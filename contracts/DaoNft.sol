// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol'; // OZ: MerkleProof
import '@openzeppelin/contracts/utils/Counters.sol';
import './ERC721A.sol';
import './DaoCredit.sol';

contract DaoNft is ERC721A, Owned {
    using Strings for uint256;
    using Counters for Counters.Counter;

    error AlreadyClaimed();
    error NotWhitelisted();

    struct Member {
        bool approved;
        uint256 status;
        uint256 last_spawn_index;
        uint256 memberTokenId;
        string name;
    }

    struct Applicant {
        bool approved;
        bool pending;
        uint256 spawn_support_num;
        string name;
        address applicant_owner;
    }

    struct NftParam {
        uint256 spawn_threshold;
        uint256 spawn_cost;
    }

    DaoCredit public memberBalance;

    Applicant[5] internal curApplicantDetail;
    NftParam public nftSetting;

    Counters.Counter private _tokenIds;
    bytes32 public merkleRoot;

    uint256 public memberAmount;
    uint256 internal indexSpawn;

    uint256 public maxSupply = 500; // Set this to your max # of NFTs for the collection
    uint256 public maxMintAmount = 1; // Set this to your max # of NFTs for any wallet

    string public myBaseURI = 'https://shdw-drive.genesysgo.net/GvvQqUbKXtR5dgWTdrz45Ab54kAfzePaC3BUf2VF7Fo8';
    string public baseExtension = '.json';

    bool public genesising = false;
    bool public paused = false;

    uint256 private mintCode;
    uint256 private spawnCode;

    address[][5] internal spawnAgree;
    address[][5] internal spawnOppose;

    mapping(address => uint256) private addressMintedBalance;
    mapping(address => Member) private addressMember;

    // mapping of address who have claimed;
    mapping(address => bool) public claimed;

    event medalClaimed(address owner);
    event ApproveCode(address member, uint256 seccode);
    event ApplyNftCode(address member, uint256 seccode);
    event SpawnAgree(address member, uint256 agreenum);

    constructor(address addrBalance) ERC721A('AbiNft', 'ABIN') {
        owner = msg.sender;

        memberBalance = DaoCredit(addrBalance);

        nftSetting.spawn_threshold = 4;
        nftSetting.spawn_cost = 100 * 10**3;

        for (uint8 i = 0; i < 5; i++) {
            curApplicantDetail[i].approved = false;
            curApplicantDetail[i].pending = false;
            curApplicantDetail[i].spawn_support_num = 0;
            curApplicantDetail[i].name = '';
            curApplicantDetail[i].applicant_owner = address(0);
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return myBaseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, '/', tokenId.toString(), baseExtension))
                : 'https://shdw-drive.genesysgo.net/GvvQqUbKXtR5dgWTdrz45Ab54kAfzePaC3BUf2VF7Fo8/collection.json';
    }

    function getNextTokenURI() public view returns (string memory) {
        uint256 supply = totalSupply();
        require(supply + 1 <= maxSupply, 'max NFT limit exceeded');

        uint256 newTokenId = supply;

        string memory currentBaseURI = myBaseURI;
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, '/', newTokenId.toString(), baseExtension))
                : 'none';
    }

    function resetMember(address _to) public onlyOwner {
        require(_to != address(0), 'to is the zero address');

        addressMember[_to].approved = false;
    }

    function approveMember(address _to) public onlyOwner returns (uint256) {
        require(!paused, 'the contract is paused');
        // require(!genesising, 'someone is genesising');
        // require(addressMember[_to].approved == false, 'approve member need to be inactived');

        uint256 supply = totalSupply();
        require(supply + 1 <= maxSupply, 'max NFT limit exceeded');

        addressMember[_to].approved = true;
        addressMember[_to].memberTokenId = 0;
        addressMember[_to].name = 'noname';

        genesising = true;

        mintCode = memberBalance.RegisterMintSync(_to);

        emit ApproveCode(_to, mintCode);

        return mintCode;
    }

    function mintOneNew(address _to, string memory memberName) public returns (uint256) {
        require(!paused, 'the contract is paused');
        require(addressMember[_to].approved == true, 'member need to be actived');
        require(addressMember[_to].memberTokenId == 0, 'member has already be minted');

        uint256 supply = totalSupply();
        require(supply + 1 <= maxSupply, 'max NFT limit exceeded');

        uint256 newTokenId = _tokenIds.current();

        addressMintedBalance[_to]++;
        _safeMint(_to, 1);

        addressMember[_to].memberTokenId = newTokenId;
        addressMember[_to].name = memberName;

        genesising = false;

        ///Sync to the Credit
        memberBalance.syncMintMember(mintCode, _to);

        memberAmount++;
        _tokenIds.increment();

        memberBalance.airdropMintforMaster(_to);

        return newTokenId;
    }

    function mintOneWhitelist(
        address _to,
        string memory memberName,
        bytes32[] calldata proof
    ) external returns (uint256) {
        require(_to != address(0), 'to is the zero address');
        uint256 supply = totalSupply();
        require(supply + 1 <= maxSupply, 'max NFT limit exceeded');

        if (claimed[_to]) revert AlreadyClaimed();

        // verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(_to));
        bool isValid = MerkleProof.verify(proof, leaf, merkleRoot);
        if (!isValid) revert NotWhitelisted();

        claimed[_to] = true;

        uint256 newTokenId = _tokenIds.current();

        addressMintedBalance[_to]++;
        _safeMint(_to, 1);

        addressMember[_to].memberTokenId = newTokenId;
        addressMember[_to].name = memberName;

        ///Sync to the Credit
        memberBalance.syncMintWhitelist(_to);

        memberAmount++;
        _tokenIds.increment();

        return newTokenId;
    }

    function upgradeMerkleRoot(bytes32 _merkleRoot) external {
        require(_merkleRoot != bytes32(0), 'merkleRoot is the zero address');
        merkleRoot = _merkleRoot;
    }

    function getMemberBalance() public view returns (address addrBalance) {
        return address(memberBalance);
    }

    function getMemberTokenId(address _to) public view returns (uint256) {
        require(_to != address(0), 'to is the zero address');
        return addressMember[_to].memberTokenId;
    }

    function applyNft(string memory _name) public returns (uint256) {
        require(!paused, 'the contract is paused');
        require(addressMember[msg.sender].approved == false, 'apply member need to be inactived');
        // require(curApplicantDetail.pending == false, 'someone is applying the member, pending');

        ///register the applying
        bool member_exist = false;
        uint8 first_found_index = 0;
        uint8 pending_amount = 0;
        for (uint8 i = 0; i < 5; i++) {
            if (curApplicantDetail[i].applicant_owner == msg.sender) {
                member_exist = true;
                break;
            } else if (curApplicantDetail[i].approved == true && first_found_index == 0) {
                first_found_index = i;
            } else if (curApplicantDetail[i].approved == false) {
                pending_amount++;
            }
        }

        require(member_exist == false, 'you already apply ');
        require(pending_amount < 5, 'apply out of amount limit for this time');

        curApplicantDetail[first_found_index].applicant_owner = msg.sender;
        curApplicantDetail[first_found_index].approved = false;
        curApplicantDetail[first_found_index].name = _name;
        curApplicantDetail[first_found_index].pending = true;

        spawnCode = memberBalance.RegisterSpawnSync(msg.sender);

        delete spawnAgree[first_found_index];

        indexSpawn++;

        memberBalance.burnSpawnSync(
            curApplicantDetail[first_found_index].applicant_owner,
            spawnCode,
            msg.sender,
            nftSetting.spawn_cost
        );

        emit ApplyNftCode(msg.sender, spawnCode);

        return indexSpawn;
    }

    function spawn() public returns (uint256) {
        // require(curApplicantDetail.pending == true && curApplicantDetail.approved == false, 'no applying NFT request');
        require(addressMember[msg.sender].approved == true, 'sender need to be actived');
        require(addressMember[msg.sender].last_spawn_index < indexSpawn, 'you already spawned this NFT');

        spawnAgree[0].push(msg.sender);

        memberBalance.burnSpawnSync(curApplicantDetail[0].applicant_owner, spawnCode, msg.sender, nftSetting.spawn_cost);

        addressMember[msg.sender].last_spawn_index = indexSpawn;

        if (spawnAgree[0].length >= nftSetting.spawn_threshold) {
            delete spawnAgree[0];
            curApplicantDetail[0].approved = true;
            curApplicantDetail[0].pending = false;

            uint256 supply = totalSupply();
            require(supply + 1 <= maxSupply, 'max NFT limit exceeded');

            memberBalance.syncSpawnMember(spawnCode, curApplicantDetail[0].applicant_owner);
            spawnCode = 0;

            addressMintedBalance[curApplicantDetail[0].applicant_owner]++;
            _safeMint(curApplicantDetail[0].applicant_owner, maxMintAmount);
            addressMember[curApplicantDetail[0].applicant_owner].approved = true;
            addressMember[curApplicantDetail[0].applicant_owner].name = curApplicantDetail[0].name;

            memberAmount++;
        }

        emit SpawnAgree(msg.sender, spawnAgree[0].length);

        return spawnAgree[0].length;
    }

    function spawnMulti(address _to) public returns (uint256) {
        // require(curApplicantDetail.pending == true && curApplicantDetail.approved == false, 'no applying NFT request');
        require(addressMember[msg.sender].approved == true, 'sender need to be actived');
        // require(addressMember[msg.sender].last_spawn_index < indexSpawn, 'you already spawned this NFT');

        ///search the applicant
        bool member_exist = false;
        uint8 found_index = 0;

        for (uint8 i = 0; i < 5; i++) {
            if (curApplicantDetail[i].applicant_owner == _to) {
                member_exist = true;
                found_index = i;
                break;
            }
        }

        if (member_exist) {
            bool spawn_exist = false;
            for (uint256 i = 0; i < spawnAgree[found_index].length; i++) {
                if (spawnAgree[found_index][i] == msg.sender) {
                    spawn_exist = true;
                    break;
                }
            }

            require(spawn_exist == false, 'you already spawn this applicant');

            spawnAgree[found_index].push(msg.sender);

            memberBalance.burnSpawnSync(
                curApplicantDetail[found_index].applicant_owner,
                spawnCode,
                msg.sender,
                nftSetting.spawn_cost
            );

            /// not necessary
            addressMember[msg.sender].last_spawn_index = indexSpawn;

            /// Check the spawn result
            if (spawnAgree[found_index].length >= nftSetting.spawn_threshold) {
                delete spawnAgree[found_index];
                curApplicantDetail[found_index].approved = true;
                curApplicantDetail[found_index].pending = false;

                uint256 supply = totalSupply();
                require(supply + 1 <= maxSupply, 'max NFT limit exceeded');

                memberBalance.syncSpawnMember(spawnCode, curApplicantDetail[found_index].applicant_owner);
                spawnCode = 0;

                ///not necessary
                addressMintedBalance[curApplicantDetail[found_index].applicant_owner]++;

                _safeMint(curApplicantDetail[found_index].applicant_owner, maxMintAmount);
                addressMember[curApplicantDetail[found_index].applicant_owner].approved = true;
                addressMember[curApplicantDetail[found_index].applicant_owner].name = curApplicantDetail[found_index].name;

                memberAmount++;
            }
        }

        emit SpawnAgree(msg.sender, spawnAgree[found_index].length);

        return spawnAgree[found_index].length;
    }

    function spawnCallback() public returns (uint256) {
        // require(curApplicantDetail.pending == true && curApplicantDetail.approved == false, 'no applying NFT request');
        require(addressMember[msg.sender].approved == true, 'sender need to be actived');
        require(addressMember[msg.sender].last_spawn_index < indexSpawn, 'you already spawned this NFT');

        if (spawnAgree[0].length > 0) {
            memberBalance.burnSpawnSync(curApplicantDetail[0].applicant_owner, spawnCode, msg.sender, nftSetting.spawn_cost);
            delete spawnAgree[0][spawnAgree.length - 1];
            spawnAgree[0].pop();
        }

        if (spawnAgree.length == 0) {
            delete spawnAgree[0];
            curApplicantDetail[0].approved = false;
            curApplicantDetail[0].pending = false;
        }

        addressMember[msg.sender].last_spawn_index = indexSpawn;

        return spawnAgree[0].length;
    }

    function spawnCallbackMulti(address _to) public returns (uint256) {
        // require(curApplicantDetail.pending == true && curApplicantDetail.approved == false, 'no applying NFT request');
        require(addressMember[msg.sender].approved == true, 'sender need to be actived');
        require(addressMember[msg.sender].last_spawn_index < indexSpawn, 'you already spawned this NFT');

        if (spawnAgree[0].length > 0) {
            memberBalance.burnSpawnSync(curApplicantDetail[0].applicant_owner, spawnCode, msg.sender, nftSetting.spawn_cost);
            delete spawnAgree[0][spawnAgree.length - 1];
            spawnAgree[0].pop();
        }

        if (spawnAgree.length == 0) {
            delete spawnAgree[0];
            curApplicantDetail[0].approved = false;
            curApplicantDetail[0].pending = false;
        }

        addressMember[msg.sender].last_spawn_index = indexSpawn;

        return spawnAgree[0].length;
    }

    function getCurApplicantName() public view returns (string memory _name) {
        return curApplicantDetail[0].name;
    }

    function getSpawnAgree() public view returns (uint256) {
        return spawnAgree[0].length;
    }

    function getMemberNextIndex() public view returns (uint256) {
        return _tokenIds.current();
    }

    function getMemberAmount() public view returns (uint256) {
        return memberAmount;
    }

    function getSpawnCost() public view returns (uint256) {
        uint256 cost = nftSetting.spawn_cost;
        return cost;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        myBaseURI = _newBaseURI;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    // nft is not transferable
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 tokenId,
        uint256 quantity
    ) internal virtual override(ERC721A) {
        require(from == address(0) || to == address(0), 'nft is not transferrable');
        super._beforeTokenTransfers(from, to, tokenId, quantity);
    }

    function isMember(address _to) public view returns (bool) {
        require(_to != address(0), 'to is zero address');
        if (addressMember[_to].approved) {
            return true;
        } else {
            return false;
        }
    }

    function getMemberName(address _to) public view returns (string memory) {
        require(_to != address(0), 'to is the zero address');
        return addressMember[_to].name;
    }

    function setMemberName(string memory _newName) public {
        addressMember[msg.sender].name = _newName;
    }

    function getSpawnThreshold() public view returns (uint256) {

        return nftSetting.spawn_threshold;
    }

    function upgradeSpawnThreshold(uint256 new_threshold) public onlyOwner {
        nftSetting.spawn_threshold = new_threshold;
    }

    function upgradeSpawnCost(uint256 new_cost) public onlyOwner {
        nftSetting.spawn_cost = new_cost;
    }
}

