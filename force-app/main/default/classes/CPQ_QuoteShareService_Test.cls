@isTest
private class CPQ_QuoteShareService_Test {
    @TestSetup
    static void setupData() {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User sharedUser = new User(
            Alias = 'shre',
            Email = 'shared.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            IsActive = true,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'shared.user@63b8c26cf65c44ad88107ec30ffd348e.com'
        );
        insert sharedUser;
        Account testAccount = new Account(Name = 'Universal Containers');
        insert testAccount;
        insert new AccountShare(
            AccountAccessLevel = 'Edit',
            AccountId = testAccount.Id,
            CaseAccessLevel = 'None',
            OpportunityAccessLevel = 'Edit',
            RowCause = 'Manual',
            UserOrGroupId = sharedUser.Id
        );
        Opportunity testOpportunity = new Opportunity(
            Name = 'XL Container',
            CloseDate = Date.today(),
            AccountId = testAccount.Id,
            StageName = 'Prospecting'
        );
        insert testOpportunity;
        insert new OpportunityShare(
            OpportunityId = testOpportunity.Id,
            OpportunityAccessLevel = 'Edit',
            RowCause = 'Manual',
            UserOrGroupId = sharedUser.Id
        );
    }

    @IsTest
    static void shareCreationWithoutOpportunity() {
        Account testAccount = [SELECT Id FROM Account];
        Test.startTest();
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(SBQQ__Account__c = testAccount.Id);
        insert testQuote;
        CPQ_QuoteShareService.syncQuoteAccessFromAccountAndOpportunity(
            new List<SBQQ__Quote__c>{ testQuote }
        );
        Test.stopTest();
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM SBQQ__Quote__Share
                WHERE
                    ParentId = :testQuote.Id
                    AND RowCause IN (:Schema.SBQQ__Quote__Share.rowCause.Opportunity__c)
            ],
            'There should not be a share from the opportunity'
        );
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM SBQQ__Quote__Share
                WHERE
                    ParentId = :testQuote.Id
                    AND RowCause IN (:Schema.SBQQ__Quote__Share.rowCause.Account__c)
            ],
            'There should be a share from the account'
        );
    }

    @IsTest
    static void shareCreationWithOpportunity() {
        Opportunity testOpportunity = [SELECT Id FROM Opportunity];
        Account testAccount = [SELECT Id FROM Account];
        Test.startTest();
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Opportunity2__c = testOpportunity.Id
        );
        insert testQuote;
        CPQ_QuoteShareService.syncQuoteAccessFromAccountAndOpportunity(
            new List<SBQQ__Quote__c>{ testQuote }
        );
        Test.stopTest();
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM SBQQ__Quote__Share
                WHERE
                    ParentId = :testQuote.Id
                    AND RowCause IN (:Schema.SBQQ__Quote__Share.rowCause.Opportunity__c)
            ],
            'There should be a share from the opportunity'
        );
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM SBQQ__Quote__Share
                WHERE
                    ParentId = :testQuote.Id
                    AND RowCause IN (:Schema.SBQQ__Quote__Share.rowCause.Account__c)
            ],
            'There should be a share from the account'
        );
    }

    @IsTest
    static void shareRemoval() {
        Account testAccount = [SELECT Id FROM Account];
        delete [
            SELECT Id
            FROM AccountShare
            WHERE AccountId = :testAccount.Id AND RowCause = 'Manual'
        ];
        Test.startTest();
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(SBQQ__Account__c = testAccount.Id);
        insert testQuote;
        CPQ_QuoteShareService.syncQuoteAccessFromAccountAndOpportunity(
            new List<SBQQ__Quote__c>{ testQuote }
        );
        Test.stopTest();
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM SBQQ__Quote__Share
                WHERE
                    ParentId = :testQuote.Id
                    AND RowCause IN (
                        :Schema.SBQQ__Quote__Share.rowCause.Opportunity__c,
                        :Schema.SBQQ__Quote__Share.rowCause.Account__c
                    )
            ],
            'There should not be any apex shares'
        );
    }
}
