// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import OZ stuff for everything. including governance, ownership, tokens(erc20, erc721)

// handles one grant per address

// vesting vault. 

contract AlloStealthFundoor {
    // this should house the main functionality for slashing, distributing tokens as well as 
    // interacting with the main allo funds allocation 

    function withdrawPayOut() public {
        // an EOA(anon) can withdraw a part of the total payout staked for it
        // it should not be able to withdraw all its stake
        // naturally should have 3 vesting schedules. 33, 33, 33 -> rest stays on the contract. goes back to protocol
        // between the 3 schedules, the anon will be sending up updates accoring to why they got the grant in the first place
        // edge case..anons will just aim to get the 1/3 of the payout..each payout could be much granular.
        // maybe a configurable % can be set due to some calculated risk appetite of the project
    }
    function delegateFundsForAnAnon() public {
        // this interacts with the allo contract to get the funds into this contract.abi
        // so some funds will be set aside for a project, which represent the project getting a grant
    }
    function slashAnonUser() public {
        // slash an anon from getting any more payouts from the system
    }
    function slashGuardian() public {
        // slash a percievd to be malicious guardian 
    }
    function confidenceThreshold() public {
        // threshold for confidence
    }
    function updateConfidenceThreshold() public {
        // owner can change this 
    }
    function getGuardian() public {
        // get details of a guardian
        // including the votes made, users slashed etc
    }
    function voteAgainstGuardian() public {
        // other guardians can vote against guardians percieved to be malicious
    }
    function slashAFlaggedAnon() public {
        // slash an anon account that has been flagged previously, from receiving any other grants from this contract
    }
    function flagAnAnon() public {
        // flag an anon percieved to be malicious
    }
    function unstake() public {
        // guardians can unstake to stop being a guardian
    }
    function stake() public {
        // accounts can stake token to become a guardian
    }
    function distribute() public {
        // distribute funds to all whitelisted anons 
        // based on varying schedules

        // can be called by the owner of the contract. which is the super admin
    }

    function getPubKey() public {}
    function setPubKey() public {}
}
