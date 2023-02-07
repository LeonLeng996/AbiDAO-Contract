//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;
pragma abicoder v2; // 0.7.0 after

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import 'hardhat/console.sol';

contract Owned {
    address internal owner;
    address internal newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract DaoCredit is Context, IERC20, IERC20Metadata, Owned {
    struct MintMember {
        bool isApproving;
        bool isSpawning;
        bool isProposalSimple;
        bool isProposalCritical;
        address memberAddress;
    }

    struct Credit {
        bool isMember;
        uint256 participation;
        uint256 execution;
        uint256 popularization;
        uint256 last_event_index;
        uint256 last_event_attend;
    }

    struct Event {
        bool approved;
        bool pending;
        uint256 eventCode;
        uint256 participation_leader;
        uint256 execution_leader;
        uint256 popularization_leader;
        uint256 participation_attender;
        uint256 execution_attender;
        uint256 popularization_attender;
        string event_address;
        address event_owner;
    }

    struct GovernParam {
        uint256 cost_propose;
        uint256 cost_vote;
        uint256 award_leader;
        uint256 award_attender;
        uint256 vote_threshold;
    }

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => Credit) private memberCredit;

    MintMember[5] private arrApproveMember;

    Event private curEventDetail;
    GovernParam private governSetting;

    uint256 private _totalSupply;
    uint256 public initialSupply;

    string private _name;
    string private _symbol;

    address public contractAddress;

    address public nftMaster;

    uint256 public indexEvent;

    uint256 public memberAmount;

    address private mintAddress;
    address private spawnAddress;
    uint256 private mintCode;
    uint256 private spawnCode;

    uint256 private vote_majority;
    uint256 private vote_resist;

    uint256 private critical_majority;
    uint256 private critical_resist;

    address[] private voteAgree;
    address[] private voteOppose;

    address[] private criticalAgree;
    address[] private criticalOppose;

    event RegisterCode(address member, uint256 seccode);
    event ProposeCode(address member, uint256 seccode);
    event VoteMajority(address member, uint256 votenum);
    event AttendTransfer(address member, uint256 votenum);

    constructor() {
        owner = msg.sender;
        _name = 'AbiToken';
        _symbol = 'ABI';

        initialSupply = 1000000 * 10**3;

        _mint(owner, initialSupply);

        memberCredit[owner].isMember = true;

        contractAddress = address(this);
        nftMaster = address(0);

        governSetting.cost_propose = 10 * 10**3;
        governSetting.cost_vote = 10 * 10**3;
        governSetting.award_leader = 300 * 10**3;
        governSetting.award_attender = 50 * 10**3;
        governSetting.vote_threshold = 3;

        for (uint8 i = 0; i < 5; i++) {
            arrApproveMember[i].isApproving = false;
            arrApproveMember[i].isSpawning = false;
            arrApproveMember[i].isProposalSimple = false;
            arrApproveMember[i].isProposalCritical = false;
            arrApproveMember[i].memberAddress = address(0);
        }
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 3;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, 'ERC20: decreased allowance below zero');
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), 'ERC20: transfer from the zero address');
        require(to != address(0), 'ERC20: transfer to the zero address');

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, 'ERC20: transfer amount exceeds balance');
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), 'ERC20: mint to the zero address');

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), 'ERC20: burn from the zero address');

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, 'ERC20: burn amount exceeds balance');
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), 'ERC20: approve from the zero address');
        require(spender != address(0), 'ERC20: approve to the zero address');

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, 'ERC20: insufficient allowance');
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function propose_simple(
        string memory event_address,
        uint256 participation_leader,
        uint256 execution_leader,
        uint256 popularization_leader,
        uint256 participation_attender,
        uint256 execution_attender,
        uint256 popularization_attender
    ) public returns (uint256) {
        require(memberCredit[msg.sender].isMember == true, 'only member can propose');
        require(balanceOf(msg.sender) >= governSetting.cost_propose, 'not enough payment to propose');
        require(participation_leader >= 0 && participation_leader <= 4, 'the leader participation upgrade is out of range');
        require(execution_leader >= 0 && execution_leader <= 4, 'the leader execution upgrade is out of range');
        require(
            popularization_leader >= 0 && popularization_leader <= 4,
            'the leader popularization upgrade is out of range'
        );
        require(
            participation_attender >= 0 && participation_attender <= 2,
            'the attender participation upgrade is out of range'
        );
        require(execution_attender >= 0 && execution_attender <= 2, 'the attender execution upgrade is out of range');
        require(
            popularization_attender >= 0 && popularization_attender <= 2,
            'the attender popularization upgrade is out of range'
        );

        curEventDetail.event_owner = msg.sender;
        curEventDetail.event_address = event_address;
        curEventDetail.participation_leader = participation_leader;
        curEventDetail.execution_leader = execution_leader;
        curEventDetail.popularization_leader = popularization_leader;
        curEventDetail.participation_attender = participation_attender;
        curEventDetail.execution_attender = execution_attender;
        curEventDetail.popularization_attender = popularization_attender;
        curEventDetail.pending = true;
        curEventDetail.approved = false;
        curEventDetail.eventCode = block.timestamp % 1000;

        delete voteAgree;
        delete voteOppose;

        vote_majority = 0;
        vote_resist = 0;

        _burn(msg.sender, governSetting.cost_propose);
        indexEvent++;

        emit ProposeCode(msg.sender, curEventDetail.eventCode);

        return curEventDetail.eventCode;
    }

    function propose_critical(
        string memory event_address,
        uint256 participation_leader,
        uint256 execution_leader,
        uint256 popularization_leader,
        uint256 participation_attender,
        uint256 execution_attender,
        uint256 popularization_attender
    ) public returns (uint256) {
        require(memberCredit[msg.sender].isMember == true, 'only member can propose');
        require(balanceOf(msg.sender) >= governSetting.cost_propose, 'not enough payment to propose');
        require(participation_leader >= 0 && participation_leader <= 4, 'the leader participation upgrade is out of range');
        require(execution_leader >= 0 && execution_leader <= 4, 'the leader execution upgrade is out of range');
        require(
            popularization_leader >= 0 && popularization_leader <= 4,
            'the leader popularization upgrade is out of range'
        );
        require(
            participation_attender >= 0 && participation_attender <= 2,
            'the attender participation upgrade is out of range'
        );
        require(execution_attender >= 0 && execution_attender <= 2, 'the attender execution upgrade is out of range');
        require(
            popularization_attender >= 0 && popularization_attender <= 2,
            'the attender popularization upgrade is out of range'
        );

        curEventDetail.event_owner = msg.sender;
        curEventDetail.event_address = event_address;
        curEventDetail.participation_leader = participation_leader;
        curEventDetail.execution_leader = execution_leader;
        curEventDetail.popularization_leader = popularization_leader;
        curEventDetail.participation_attender = participation_attender;
        curEventDetail.execution_attender = execution_attender;
        curEventDetail.popularization_attender = popularization_attender;
        curEventDetail.pending = true;
        curEventDetail.approved = false;
        curEventDetail.eventCode = block.timestamp % 1000;

        delete criticalAgree;
        delete criticalOppose;

        critical_majority = 0;
        critical_resist = 0;

        _burn(msg.sender, governSetting.cost_propose);
        indexEvent++;

        emit ProposeCode(msg.sender, curEventDetail.eventCode);

        return curEventDetail.eventCode;
    }

    function getCurEventAddress() public view returns (string memory event_address) {
        return curEventDetail.event_address;
    }

    function vote_simple(bool agree) public returns (uint256) {
        require(memberCredit[msg.sender].isMember == true, 'only member can vote');
        require(balanceOf(msg.sender) >= governSetting.cost_vote, 'not enough payment to vote');
        require(memberCredit[msg.sender].last_event_index < indexEvent, 'you can only vote once for one event');

        if (agree) {
            voteAgree.push(msg.sender);
        } else {
            voteOppose.push(msg.sender);
        }

        memberCredit[msg.sender].last_event_index = indexEvent;

        _burn(msg.sender, governSetting.cost_vote);

        if (voteAgree.length > voteOppose.length) {
            vote_majority = voteAgree.length - voteOppose.length;
            vote_resist = 0;
        } else {
            vote_resist = voteOppose.length - voteAgree.length;
            vote_majority = 0;
        }

        if (vote_majority >= governSetting.vote_threshold) {
            delete voteAgree;
            delete voteOppose;

            curEventDetail.pending = false;
            curEventDetail.approved = true;
        }

        if (vote_resist >= governSetting.vote_threshold) {
            delete voteAgree;
            delete voteOppose;

            curEventDetail.pending = false;
            curEventDetail.approved = false;
        }

        if (vote_resist > vote_majority) {
            emit ProposeCode(msg.sender, vote_resist + 1000);
            return vote_resist + 1000;
        }

        emit VoteMajority(msg.sender, vote_majority);

        return vote_majority;
    }

    function vote_critical(bool agree) public returns (uint256) {
        require(memberCredit[msg.sender].isMember == true, 'only member can vote');
        require(balanceOf(msg.sender) >= governSetting.cost_vote, 'not enough payment to vote');
        require(memberCredit[msg.sender].last_event_index < indexEvent, 'you can only vote once for one event');

        if (agree) {
            criticalAgree.push(msg.sender);
        } else {
            criticalOppose.push(msg.sender);
        }

        memberCredit[msg.sender].last_event_index = indexEvent;

        _burn(msg.sender, governSetting.cost_vote);

        uint256 attender_theshold = memberAmount / 2;
        uint256 pass_theshold = (2 * (criticalAgree.length + criticalOppose.length)) / 3;

        if ((2 * criticalOppose.length + 2 * criticalAgree.length) >= attender_theshold) {
            if (criticalAgree.length > criticalOppose.length) {
                critical_majority = criticalAgree.length - criticalOppose.length;
                critical_resist = 0;
            } else {
                critical_resist = criticalOppose.length - criticalAgree.length;
                critical_majority = 0;
            }

            if (critical_majority >= pass_theshold) {
                delete criticalAgree;
                delete criticalOppose;

                curEventDetail.pending = false;
                curEventDetail.approved = true;
            }

            if (critical_resist >= (memberAmount - pass_theshold)) {
                delete criticalAgree;
                delete criticalOppose;

                curEventDetail.pending = false;
                curEventDetail.approved = false;
            }
        }

        if (critical_resist > critical_majority) {
            emit ProposeCode(msg.sender, critical_resist + 1000);
            return critical_resist + 1000;
        }

        emit VoteMajority(msg.sender, critical_majority);

        return critical_majority;
    }

    function getVoteMajority() public view returns (uint256) {
        if (vote_resist > vote_majority) return vote_resist + 1000;

        return vote_majority;
    }

    function attend_simple(uint256 eventCode) public returns (uint256) {
        require(memberCredit[msg.sender].isMember == true, 'only member can attend');
        require(curEventDetail.approved == true, 'can only attend active event');
        require(memberCredit[msg.sender].last_event_attend < indexEvent, 'you can only attend once for one event');
        require(eventCode == curEventDetail.eventCode, 'event code is not correct');

        uint256 transfer_amount;
        uint256 new_value;
        uint256 old_value;
        uint256 credit1;
        uint256 credit2;
        uint256 credit3;
        uint256 weight;

        memberCredit[msg.sender].last_event_attend = indexEvent;

        old_value = memberCredit[msg.sender].participation * 3;
        credit1 = old_value / 10;

        old_value = memberCredit[msg.sender].execution * 3;
        credit2 = old_value / 10;

        old_value = memberCredit[msg.sender].popularization * 4;
        credit3 = old_value / 10;

        old_value = credit1 + credit2;
        require(old_value >= credit1);
        new_value = old_value + credit3;
        require(new_value >= old_value);
        weight = new_value;

        if (curEventDetail.event_owner == msg.sender) {
            if (memberCredit[msg.sender].participation < 256) {
                old_value = memberCredit[msg.sender].participation;
                new_value = old_value + curEventDetail.participation_leader;
                require(new_value >= old_value);
                memberCredit[msg.sender].participation = new_value;
            }
            if (memberCredit[msg.sender].execution < 256) {
                old_value = memberCredit[msg.sender].execution;
                new_value = old_value + curEventDetail.execution_leader;
                require(new_value >= old_value);
                memberCredit[msg.sender].execution = new_value;
            }
            if (memberCredit[msg.sender].popularization < 256) {
                old_value = memberCredit[msg.sender].popularization;
                new_value = old_value + curEventDetail.popularization_leader;
                require(new_value >= old_value);
                memberCredit[msg.sender].popularization = new_value;
            }

            old_value = weight;
            new_value = governSetting.award_leader * old_value;

            old_value = new_value / 256;
            new_value = old_value + governSetting.award_leader;
            require(new_value >= old_value);
            transfer_amount = new_value;

            _transfer(owner, msg.sender, transfer_amount);
        } else {
            if (memberCredit[msg.sender].participation < 256) {
                old_value = memberCredit[msg.sender].participation;
                new_value = old_value + curEventDetail.participation_attender;
                require(new_value >= old_value);
                memberCredit[msg.sender].participation = new_value;
            }
            if (memberCredit[msg.sender].execution < 256) {
                old_value = memberCredit[msg.sender].execution;
                new_value = old_value + curEventDetail.execution_attender;
                require(new_value >= old_value);
                memberCredit[msg.sender].execution = new_value;
            }
            if (memberCredit[msg.sender].popularization < 256) {
                old_value = memberCredit[msg.sender].popularization;
                new_value = old_value + curEventDetail.popularization_attender;
                require(new_value >= old_value);
                memberCredit[msg.sender].popularization = new_value;
            }

            old_value = weight;
            new_value = governSetting.award_attender * old_value;

            old_value = new_value / 256;
            new_value = old_value + governSetting.award_attender;
            require(new_value >= old_value);
            transfer_amount = new_value;

            _transfer(owner, msg.sender, transfer_amount);
        }

        emit AttendTransfer(msg.sender, transfer_amount);

        return transfer_amount;
    }

    function weightOfCredit(address _to) public view returns (uint256) {
        require(memberCredit[msg.sender].isMember == true, 'only member can attend');
        uint256 new_value;
        uint256 old_value;
        uint256 credit1;
        uint256 credit2;
        uint256 credit3;

        old_value = memberCredit[_to].participation * 3;
        credit1 = old_value / 10;

        old_value = memberCredit[_to].execution * 3;
        credit2 = old_value / 10;

        old_value = memberCredit[_to].popularization * 4;
        credit3 = old_value / 10;

        old_value = credit1 + credit2;
        require(old_value >= credit1);
        new_value = old_value + credit3;
        require(new_value >= old_value);

        return new_value;
    }

    function upgradeNftMaster(address newNftMaster) public onlyOwner {
        nftMaster = newNftMaster;
    }

    function upgradeCostPropose(uint256 newCostPropose) public onlyOwner {
        governSetting.cost_propose = newCostPropose;
    }

    function upgradeCostVote(uint256 newCostVote) public onlyOwner {
        governSetting.cost_vote = newCostVote;
    }

    function upgradeAwardLeader(uint256 newAwardLeader) public onlyOwner {
        governSetting.award_leader = newAwardLeader;
    }

    function upgradeAwardAttender(uint256 newAwardAttender) public onlyOwner {
        governSetting.award_attender = newAwardAttender;
    }

    function upgradeVoteThreshold(uint256 newVoteThreshold) public onlyOwner {
        governSetting.vote_threshold = newVoteThreshold;
    }

    function isEventApproved() public view returns (bool) {
        return curEventDetail.approved;
    }

    function isEventOwner() public view returns (bool) {
        return (curEventDetail.event_owner == msg.sender);
    }

    function getNftMaster() public view returns (address addrNftMaster) {
        return address(nftMaster);
    }

    function airdropMintforMaster(address _to) public {
        require(msg.sender == nftMaster, 'only can airdrop from nftMaster');
        _transfer(owner, _to, 500 * 10**3);
    }

    function getEventIndex() public view returns (uint256) {
        return indexEvent;
    }

    function isNftMember() public view returns (bool) {
        return memberCredit[msg.sender].isMember;
    }

    function getMemberParticipation(address _add) public view returns (uint256) {
        return memberCredit[_add].participation;
    }

    function getMemberExecution(address _add) public view returns (uint256) {
        return memberCredit[_add].execution;
    }

    function getMemberPopularization(address _add) public view returns (uint256) {
        return memberCredit[_add].popularization;
    }

    function getCostPropose() public view returns (uint256) {
        return governSetting.cost_propose;
    }

    function burnMintSync(
        address accountWant,
        uint256 code,
        address accountBurn,
        uint256 amount
    ) public returns (uint256) {
        require(accountBurn != address(0), 'ERC20: burn from the zero address');
        require(mintAddress == accountWant, 'drop bomb address is wrong');
        require(code == mintCode, 'burnner sync code is wrong');

        _beforeTokenTransfer(accountBurn, address(0), amount);

        uint256 accountBalance = _balances[accountBurn];
        require(accountBalance >= amount, 'ERC20: burn mint amount exceeds balance');
        unchecked {
            _balances[accountBurn] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(accountBurn, address(0), amount);

        _afterTokenTransfer(accountBurn, address(0), amount);

        return balanceOf(accountBurn);
    }

    function burnSpawnSync(
        address accountWant,
        uint256 code,
        address accountBurn,
        uint256 amount
    ) public returns (uint256) {
        require(accountBurn != address(0), 'ERC20: burn from the zero address');
        // require(spawnAddress == accountWant, 'drop spawn bomb address is wrong');
        // require(code == spawnCode, 'burnner spawn code is wrong');
        require(msg.sender == nftMaster, 'only burn spawn sync by nftMaster');

        _beforeTokenTransfer(accountBurn, address(0), amount);

        uint256 accountBalance = _balances[accountBurn];
        require(accountBalance >= amount, 'burn spawn amount exceeds balance');
        unchecked {
            _balances[accountBurn] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(accountBurn, address(0), amount);

        _afterTokenTransfer(accountBurn, address(0), amount);

        return balanceOf(accountBurn);
    }

    function RegisterMintSync(address accountSync) public returns (uint256) {
        require(msg.sender == nftMaster, 'only register sync by nftMaster');

        ///register the approving
        bool member_exist = false;
        uint8 first_found_index = 0;
        for (uint8 i = 0; i < 5; i++) {
            if (arrApproveMember[i].memberAddress == accountSync) {
                member_exist = true;
                break;
            } else if (arrApproveMember[i].isApproving == false && first_found_index == 0) {
                first_found_index = i;
            }
        }

        if (member_exist == false) {
            arrApproveMember[first_found_index].memberAddress = accountSync;
            arrApproveMember[first_found_index].isApproving = true;
        }

        mintAddress = accountSync;
        mintCode = block.timestamp % 1000;

        emit RegisterCode(accountSync, mintCode);

        return mintCode;
    }

    function RegisterSpawnSync(address accountSync) public returns (uint256) {
        require(msg.sender == nftMaster, 'only register spawn by nftMaster');

        spawnAddress = accountSync;
        spawnCode = block.timestamp % 1000;

        emit RegisterCode(accountSync, spawnCode);

        return spawnCode;
    }

    function syncMintMember(uint256 code, address account) public returns (bool) {
        // require(code == mintCode, 'sync code is wrong');
        require(msg.sender == nftMaster, 'only sync mint by nftMaster');

        ///register the approving
        bool member_exist = false;
        for (uint8 i = 0; i < 5; i++) {
            if (arrApproveMember[i].memberAddress == account && arrApproveMember[i].isApproving == true) {
                arrApproveMember[i].isApproving = false;
                member_exist = true;
                break;
            }
        }

        memberCredit[account].isMember = true;
        memberAmount++;

        return memberCredit[account].isMember;
    }

    function syncSpawnMember(uint256 code, address account) public returns (bool) {
        // require(code == spawnCode, 'spawn code is wrong');
        require(msg.sender == nftMaster, 'only sync spawn by nftMaster');

        memberCredit[account].isMember = true;
        memberAmount++;

        return memberCredit[account].isMember;
    }

    function syncMintWhitelist(address account) public returns (bool) {
        require(msg.sender == nftMaster, 'only sync mint by nftMaster');

        memberCredit[account].isMember = true;
        memberAmount++;

        return memberCredit[account].isMember;
    }
}
