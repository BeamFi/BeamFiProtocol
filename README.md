# BeamFi Protocol

BeamFi Protocol is a Micro Payments Solution for transferring a continuous stream of money or values represented by the tokens in real-time without intermediaries.

[![Watch BeamFi Meeting App Demo with Zoom](/guide/images/meeting-app.png)](https://youtu.be/85TWP4QHHBg)

[**Watch BeamFi Meeting App Demo**](https://youtu.be/85TWP4QHHBg)

## What problems does it solve?

- Remove the intermediaries and their fees, putting the power back to the users.
- Real-time utilization of streamed money increases the utility of capital and the economic efficiency of idle money.
- Solve the long-term job problem - Why are workers still paid at the end of the month/job?
- Bring fairness, as with lump-sum payment, one party always has an advantage.
- Users will have full ownership of their payment data and how it can be used to provide analytics services or insights to them, by allowing 3rd party companies to read their data with their consent

![Autonomous Streams](/guide/images/autonomous.png)

## Getting Started Guide

See [BeamFi Developer Documentation](https://developer.beamfi.app) for getting started, architecture, API, integration with Web frontend, deployment and sample apps.  
See [BeamFi Pitch Deck](https://pitch.com/public/24972b6a-11d1-4690-8215-a2b44767d68a) for its vision.  
See [BeamFi Payment Protocol](https://devpost.com/software/beam-payment-protocol-by-content-fly) in Supernova Hackathorn 2022. Top 7 submissions in DeFi.

## Folder Structure

`backend/service` - Motoko Actor Smart Contract where the canister entry point is.  
`backend/model` - Motoko model types for Beam, BeamOut, Escrow and persistence store helper  
`backend/utils` - Common utility modules  
`diagram` - BeamFi architecture (Install Draw.io integration VSCode extension to view it)  
`scripts` - CI / CD automation scripts

## Architecture

BeamFi Protocol Architecture  
![BeamFi Protocol](/guide/images/architecture.png)

BeamFi Zoom Integration Architecture  
![BeamFi Protocol](/guide/images/BeamFiZoomIntegrationArchitecture.png)

## Roadmap

- [x] Backend - Implement basic BeamFi Protocol Streaming smart contracts
- [x] Backend - BeamFi protocol canister running independently, separated from Content Fly
- [x] Frontend - Design and implement BeamFi app, integrating with BeamFi Protocol
- [x] Frontend - Plug Wallet integration with BeamFi
- [x] Backend - Integrate Stablecoin XTC Cycles Token
- [x] Frontend/Backend - BeamFi Meeting App with Zoom integration
- [x] Frontend - [BeamFi Meeting App](https://marketplace.zoom.us/apps/sjH1I9WvT4O7Si2R61bbSg) approved in Zoom Marketplace
- [x] Backend - Research and implement a cost-effective way to stream using the IC new Timer API
- [x] Backend - Allow Beam start/stop/restart
- [x] Frontend - NFID integration with BeamFi
- [x] Test - Automated Smart Contract API tests
- [x] Doc - Developer Documentation and API Documentation
- [ ] Backend - Bitcoin ckBTC support
- [ ] Frontend - Native Bitcoin support
- [ ] Frontend - Client SDK (TypeScript)
- [ ] Frontend - Connect to different BeamFi Vaults, and switch between them
- [ ] Backend - BeamFi Protocol 3.0 (Rate-based Continuous Streaming Beam)

## License

See the [License](License) file for license rights and limitations (MIT).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details about how to contribute to this project.

## Authors

Code & Architecture: Henry Chan, [henry@beamfi.app](mailto:henry@beamfi.app), Twitter: [@kinwo](https://twitter.com/kinwo)  
Product & Vision: Sam McCallum, [sam@beamfi.app](mailto:sam@beamfi.app)

## References

- [Internet Computer](https://internetcomputer.org)
- [Motoko](https://internetcomputer.org/docs/current/motoko/main/motoko)
- [NextJS IC Starter](https://github.com/dappblock/nextjs-ic-starter/)
- [Vessel Package Manager](https://github.com/dfinity/vessel)
