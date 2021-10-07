# CPQ Quote Share Sync

This repo contains a service class that can be used to mirror Opportunity shares granted both on the opportunity and the opportunity's parent account to the quote.

This should be used in situations where you would like a quote to get its shares from the opportunity as it would through a master-detail relationship with the opportunity.

## Org Installation Notes

1. Make sure that the account, opportunity, and quote access is set to private or read only

2. <a href="https://githubsfdeploy.herokuapp.com?owner=dmgerow&repo=cpq-quote-share-sync">
     <img alt="Deploy to Salesforce"
          src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
   </a>

3. Call the `CPQ_QuoteShareService` from your triggers, batch jobs, etc.

4. Update the test class to make sure that it passes in your org

## Scratch Org Notes

You can make a scratch org with CPQ installed using the following command:

```bash
npm run crate:scratch
```
