# How to contribute

## Git Branches

dev - all development code will first merge to dev, any push to dev will trigger a deployment to https://dev.beamfi.app  
main - this is where the production stable code is, it requires a manual trigger in Github Action to deploy to https://beamfi.app

## Pull Request & Review

- When working on a new feature, create a new feature branch and work on it there.
- When it is ready for testing or review, submit a Pull Request to the dev branch.
- The main contributor will review and give feedback.
- When the review is complete, the PR will be merged to dev for testers to try it in frontend
- When it passed the manual human tests, new changes will be merged to the main branch and the manager can trigger Github Action to deploy to production.
