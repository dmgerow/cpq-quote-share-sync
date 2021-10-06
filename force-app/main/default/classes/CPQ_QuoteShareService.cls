public with sharing class CPQ_QuoteShareService {
    public static Boolean hasSharingRun = false;

    public static void createQuoteAccess(List<SBQQ__Quote__c> newQuotes) {
        // This logic uses a large number of queries and should never need to run twice during a
        // transaction. This boolean makes sure that the logic only runs once.
        if (hasSharingRun) {
            return;
        }
        hasSharingRun = true;
        Set<Id> accountIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();
        for (SBQQ__Quote__c quote : newQuotes) {
            accountIds.add(quote.SBQQ__Account__c);
            if (quote.SBQQ__Opportunity2__c != null) {
                opportunityIds.add(quote.SBQQ__Opportunity2__c);
            }
        }

        Map<Id, List<AccountShare>> accountSharesByAccountId = getAccountSharesByAccountId(
            accountIds
        );
        Map<Id, List<OpportunityShare>> opportunitySharesByOpportunityId = getOpportunitySharesByOpportunityId(
            opportunityIds
        );
        Map<Id, Map<String, SBQQ__Quote__Share>> currentQuoteSharesByUniqueIdAndQuoteId = getCurrentQuoteShares(
            newQuotes
        );

        List<SBQQ__Quote__Share> quoteSharesToCreate = new List<SBQQ__Quote__Share>();
        List<SBQQ__Quote__Share> quoteSharesToDelete = new List<SBQQ__Quote__Share>();

        for (SBQQ__Quote__c newQuote : newQuotes) {
            Map<String, SBQQ__Quote__Share> newQuoteSharesByUniqueId = new Map<String, SBQQ__Quote__Share>();
            if (
                newQuote.SBQQ__Opportunity2__c != null &&
                opportunitySharesByOpportunityId.containsKey(newQuote.SBQQ__Opportunity2__c)
            ) {
                for (
                    OpportunityShare oppShare : opportunitySharesByOpportunityId.get(
                        newQuote.SBQQ__Opportunity2__c
                    )
                ) {
                    SBQQ__Quote__Share quoteShare = new SBQQ__Quote__Share();
                    quoteShare.ParentId = newQuote.Id;
                    quoteShare.UserOrGroupId = oppShare.UserOrGroupId;
                    quoteShare.AccessLevel = oppShare.OpportunityAccessLevel == 'All'
                        ? 'Edit'
                        : oppShare.OpportunityAccessLevel;
                    quoteShare.RowCause = Schema.SBQQ__Quote__Share.rowCause.Opportunity__c;
                    newQuoteSharesByUniqueId.put(
                        generateQuoteShareUniqueId(quoteShare),
                        quoteShare
                    );
                }
            }
            if (accountSharesByAccountId.containsKey(newQuote.SBQQ__Account__c)) {
                for (
                    AccountShare accShare : accountSharesByAccountId.get(newQuote.SBQQ__Account__c)
                ) {
                    SBQQ__Quote__Share quoteShare = new SBQQ__Quote__Share();
                    quoteShare.ParentId = newQuote.Id;
                    quoteShare.UserOrGroupId = accShare.UserOrGroupId;
                    quoteShare.AccessLevel = accShare.OpportunityAccessLevel == 'All'
                        ? 'Edit'
                        : accShare.OpportunityAccessLevel;
                    quoteShare.RowCause = Schema.SBQQ__Quote__Share.rowCause.Account__c;
                    newQuoteSharesByUniqueId.put(
                        generateQuoteShareUniqueId(quoteShare),
                        quoteShare
                    );
                }
            }

            if (currentQuoteSharesByUniqueIdAndQuoteId.containsKey(newQuote.Id)) {
                Map<String, SBQQ__Quote__Share> currentQuoteSharesByUniqueId = currentQuoteSharesByUniqueIdAndQuoteId.get(
                    newQuote.Id
                );
                for (String uniqueId : currentQuoteSharesByUniqueId.keyset()) {
                    if (!newQuoteSharesByUniqueId.containsKey(uniqueId)) {
                        quoteSharesToDelete.add(currentQuoteSharesByUniqueId.get(uniqueId));
                    }
                }
                for (String uniqueId : newQuoteSharesByUniqueId.keyset()) {
                    if (!currentQuoteSharesByUniqueId.containsKey(uniqueId)) {
                        quoteSharesToCreate.add(newQuoteSharesByUniqueId.get(uniqueId));
                    }
                }
            } else {
                quoteSharesToCreate.addall(newQuoteSharesByUniqueId.values());
            }
        }

        if (quoteSharesToCreate.size() > 0) {
            insert removeInactiveShares(quoteSharesToCreate);
        }
        delete quoteSharesToDelete;
    }

    private static Map<Id, List<AccountShare>> getAccountSharesByAccountId(Set<Id> accountIds) {
        Map<Id, List<AccountShare>> accountSharesByAccountId = new Map<Id, List<AccountShare>>();
        for (AccountShare accountShare : [
            SELECT Id, RowCause, AccountId, UserOrGroupId, OpportunityAccessLevel
            FROM AccountShare
            WHERE OpportunityAccessLevel != 'None' AND AccountId IN :accountIds
        ]) {
            List<AccountShare> accountShares = new List<AccountShare>{ accountShare };
            if (accountSharesByAccountId.containsKey(accountShare.AccountId)) {
                accountShares.addAll(accountSharesByAccountId.get(accountShare.Accountid));
            }
            accountSharesByAccountId.put(accountShare.AccountId, accountShares);
        }
        return accountSharesByAccountId;
    }

    private static Map<Id, List<OpportunityShare>> getOpportunitySharesByOpportunityId(
        Set<Id> opportunityIds
    ) {
        Map<Id, List<OpportunityShare>> opportunitySharesByOpportunityId = new Map<Id, List<OpportunityShare>>();
        for (OpportunityShare OpportunityShare : [
            SELECT Id, RowCause, OpportunityId, UserOrGroupId, OpportunityAccessLevel
            FROM OpportunityShare
            WHERE OpportunityId IN :opportunityIds
        ]) {
            List<OpportunityShare> opportunityShares = new List<OpportunityShare>{
                opportunityShare
            };
            if (opportunitySharesByOpportunityId.containsKey(opportunityShare.OpportunityId)) {
                opportunityShares.addAll(
                    opportunitySharesByOpportunityId.get(opportunityShare.OpportunityId)
                );
            }
            opportunitySharesByOpportunityId.put(opportunityShare.OpportunityId, opportunityShares);
        }
        return opportunitySharesByOpportunityId;
    }

    private static Map<Id, Map<String, SBQQ__Quote__Share>> getCurrentQuoteShares(
        List<SBQQ__Quote__c> newQuotes
    ) {
        Map<Id, Map<String, SBQQ__Quote__Share>> quoteSharesByUniqueIdAndQuoteId = new Map<Id, Map<String, SBQQ__Quote__Share>>();
        for (SBQQ__Quote__Share currentQuoteShare : [
            SELECT Id, ParentId, UserOrGroupId, RowCause
            FROM SBQQ__Quote__Share
            WHERE
                ParentId IN :newQuotes
                AND RowCause IN (
                    :Schema.SBQQ__Quote__Share.rowCause.Opportunity__c,
                    :Schema.SBQQ__Quote__Share.rowCause.Account__c
                )
        ]) {
            Map<String, SBQQ__Quote__Share> quoteSharesByUniqueId = new Map<String, SBQQ__Quote__Share>();
            if (quoteSharesByUniqueIdAndQuoteId.containsKey(currentQuoteShare.ParentId)) {
                quoteSharesByUniqueId = quoteSharesByUniqueIdAndQuoteId.get(
                    currentQuoteShare.ParentId
                );
            }
            quoteSharesByUniqueId.put(
                generateQuoteShareUniqueId(currentQuoteShare),
                currentQuoteShare
            );
            quoteSharesByUniqueIdAndQuoteId.put(currentQuoteShare.ParentId, quoteSharesByUniqueId);
        }
        return quoteSharesByUniqueIdAndQuoteId;
    }

    private static String generateQuoteShareUniqueId(SBQQ__Quote__Share quoteShare) {
        String uniqueId = quoteShare.ParentId;
        uniqueId += quoteShare.UserOrGroupId;
        uniqueId += quoteShare.RowCause;
        return uniqueId;
    }

    private static List<SBQQ__Quote__Share> removeInactiveShares(
        List<SBQQ__Quote__Share> newShares
    ) {
        List<SBQQ__Quote__Share> actievSharesToInsert = new List<SBQQ__Quote__Share>();
        List<SBQQ__Quote__Share> userShares = new List<SBQQ__Quote__Share>();
        List<SBQQ__Quote__Share> groupShares = new List<SBQQ__Quote__Share>();
        Set<Id> userIds = new Set<Id>();
        Set<Id> groupIds = new Set<Id>();
        SobjectType userSobjectType = User.getSObjectType();
        SobjectType groupSobjectType = Group.getSObjectType();
        for (SBQQ__Quote__Share newShare : newShares) {
            if (newShare.UserOrGroupId.getSobjectType() == userSobjectType) {
                userIds.add(newShare.UserOrGroupId);
                userShares.add(newShare);
            } else if (newShare.UserOrGroupId.getSobjectType() == groupSobjectType) {
                groupIds.add(newShare.UserOrGroupId);
                groupShares.add(newShare);
            } else {
                actievSharesToInsert.add(newShare);
            }
        }
        Map<Id, User> activeUsersById = new Map<Id, User>(
            [
                SELECT Id
                FROM User
                WHERE IsActive = TRUE AND Id IN :userIds
                ORDER BY SystemModstamp ASC
            ]
        );
        Map<Id, Group> groupsById = new Map<Id, Group>(
            [SELECT Id FROM Group WHERE Id IN :groupIds]
        );
        for (SBQQ__Quote__Share userShare : userShares) {
            if (activeUsersById.containsKey(userShare.UserOrGroupId)) {
                actievSharesToInsert.add(userShare);
            }
        }
        for (SBQQ__Quote__Share groupShare : groupShares) {
            if (groupsById.containsKey(groupShare.UserOrGroupId)) {
                actievSharesToInsert.add(groupShare);
            }
        }
        return actievSharesToInsert;
    }
}
