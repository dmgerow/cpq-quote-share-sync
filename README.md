# CPQ Quote Share Sync

This repo contains a service class that can be used to mirror Opportunity shares granted both on the opportunity and the opportunity's parent account to the quote.

This should be used in situations where you would like a quote to get its shares from the opportunity as it would through a master-detail relationship with the opportunity.

## Org Installation Notes

1. Make sure that the account, opportunity, and quote access is set to private or read only

2. <a href="https://githubsfdeploy.herokuapp.com?owner=dmgerow&repo=cpq-quote-share-sync&ref=main">
     <img alt="Deploy to Salesforce"
          src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
   </a>

3. Call the `CPQ_QuoteShareService` from your triggers, batch jobs, etc.

```java
CPQ_QuoteShareService.syncQuoteAccessFromAccountAndOpportunity(quoteList); //where quoteList is a list of quotes
```

4. Update the test class to make sure that it passes in your org

## Implementation Considerations

- This should be implemented in triggers very sparingly. Calling it from any trigger except the quote will put you at risk of hitting governor limits.
- Consider creating a scheduled batch job to call this code so that sharing is recalculated for quotes in a specific criteria. The code only creates or deletes shares if the change is required, so you should not have to worry about locking quotes while people are working on them or other unnecessary database activity.
- Test this a lot before using it in production

## Scratch Org Notes

First, make sure that all of the npm modules are installed

```bash
npm install
```

Then, you can make a scratch org with CPQ installed using the following command:

```bash
npm run crate:scratch
```
