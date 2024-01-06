// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Initiative {
    using SafeERC20 for IERC20;

    // events
    // InitiativeCreated
    // InitiativeCall
    // InitiativeClose

    // event: add collateral for initiative

    struct InitiativeStruct {
        string Description;
        uint256 initiativeId;
        // initiativeCreator that thought of this
        address Creator;
        // representing amount of pool funds to be allocated to this initiative
        uint256 CurrentFundsAllocated;
        // guardians first have to clear this initiative for funding
        bool isClearedForFunding;
        // if funding goal is reached, then the funds can be streamed to a selected knight
        // if there is no selected knight at this time, funds remain in the pool for a set amount of time
        // other wise refunds are sent back to all concerned parties.
        bool isFundingComplete;
        // users who funded the initiative are added here, to decided how funds are used
        // they have some voting power to veto the course of the initative

        // guardians can vote, voters can vote, the creator of the initiative also has some funds allocated to it
        address[] Voters;
        // the knights are in charge of carrying out the initiative
        // they are vetted by the guardians and community at large
        // they are assumed to be skilled individuals, or bounty hunters
        // they are streamed part of the funds from the pool

        // if they default at any milestone, they can be slashed and removed as a knight from the platform if they get 3 strikes or majority decision
        address[] Knights;
    }

    mapping(uint256 => InitiativeStruct) private initiatives;

    struct InitiativeReferences {
        address InitiativeManager;
        address GuildToken;
    }

    InitiativeReferences internal refs;

    struct InitiativeParams {
        uint256 openingFee;
        uint256 maxFundable;
    }

    InitiativeParams internal params;

    constructor(InitiativeParams memory _params, InitiativeReferences memory _refs) {
        refs = _refs;
        params = _params;
    }

    function setInitiativeManager() public {}
    function createInitiative() public {}
    function fundInitiative() public {}

    function getReferences() external view returns (InitiativeReferences memory) {
        return refs;
    }

    function getParameters() external view returns (InitiativeParams memory) {
        return params;
    }

    function getInitiative(uint256 initiativeId) external view returns (InitiativeStruct memory) {
        return initiatives[initiativeId];
    }

    function assignKnights() public {}
}
