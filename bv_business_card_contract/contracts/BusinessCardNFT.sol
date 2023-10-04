// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// 전송할 Business Card가 없을 때 뜰 커스텀 오류
error No_Business_Card_To_Transfer();

contract BusinessCardNFT is ERC721URIStorage, ReentrancyGuard{
    using Counters for Counters.Counter;

    // 명함에 들어갈 정보 구조
    struct BusinessCardInfo {
        string name;    // 이름
        string mbti;    // mbti
        string phone;   // 연락처
        string company; // 회사
        address issuer; // 명함 주인 지갑 주소
    }

    // 명함이 전송될 때 위치 (위도, 경도)
    struct BusinessCardTransferLocation {
        string lat;
        string lng;
    }

    // mapping
    // BusinessCardInfo
    mapping(address => BusinessCardInfo) private _bcInfo;
    // 명함 주인이 발행한 명함들(tokenId)을 담을 동적 배열
    mapping(address => uint[]) private _tokenIdsMadeByIssuer;
    // 명함 주인이 명함(tokenId)를 전송할 때 위치 정보
    mapping(uint => BusinessCardTransferLocation) private _tokenIdTransferLocation;
    // 명함(tokenId)이 현재 issuer에게 있는지, 있으면 true 없으면 false
    mapping(address => mapping(uint => bool)) private _isTokenOwnedByIssuer;
    // 명함 주인이 가진 명함 갯수 = 발급한 양 - 다른 사람에게 전송한 양
    mapping(address => uint) private _amountOfTokenOwnedByIssuer;
    // 명함 민팅 횟수 체크
    mapping(address => uint) private _checkAmountOfTokenMint;
    // 명함을 가졌는지 체크
    mapping(address => uint) private _checkAmountOfTokenOwnedExceptIssuer;

    uint public MAX_BUSINESS_CARD = 1;      // 한 사람 당 가질 수 있는 내 명함 개수
    uint public MINT_AMOUNTS = 5;           // 한 번 민팅할 때 민팅할 양
    uint public MINT_PRICE = 0.01 ether;    // 한 번 민팅할 때 민팅 가격

    Counters.Counter private _tokenIds;

    // event
    // 명함 정보 event
    event BusinessCardInfoRegistered(address indexed issuer, string name, string mbti, string phone, string company);
    // 명함 민팅 event
    event BusinessCardMinted(uint indexed tokenId, address issuer, uint amountOfTokenOwnedByIssuer);
    // 명함 전송 event
    event BusinessCardTransfered(address indexed to, address from, uint tokenId, uint amountOfTokenOwnedByIssuer);

    // modifier
    modifier isBusinessCardInfoRegistered {
        BusinessCardInfo memory myBusinessCardInfo = _bcInfo[msg.sender];
        require(keccak256(abi.encodePacked(myBusinessCardInfo.name)) != keccak256(abi.encodePacked("")), "Register your business card first");
        _;
    }

    // ERC721 Contract : constructor를 가면 _name, _symbol의 형태로 작성되어 있음
    constructor() ERC721("BusinessCard", "BC") {}

    // function
    /**
     * @dev 명함 정보를 등록하는 함수
     * @param _name 명함에 들어갈 이름
     * @param _mbti 명함에 들어갈 mbti
     * @param _phone 명함에 들어갈 연락처
     * @param _company 명함에 들어갈 회사
     */
    function resgisterBusinessCardInfo(string memory _name, string memory _mbti, string memory _phone, string memory _company) public {
        BusinessCardInfo memory businessCardInfo = BusinessCardInfo({
            name: _name,
            mbti: _mbti,
            phone: _phone,
            company: _company,
            issuer: msg.sender
        });
        _bcInfo[msg.sender] = businessCardInfo;
        // emit : event를 발생시킬 경우 사용하는 키워드
        emit BusinessCardInfoRegistered(msg.sender, _name, _mbti, _phone, _company);
    }

    /**
     * @dev BusinessCard를 민팅하는 함수, MINT_AMOUNTS개씩 민팅 가능
     * @param tokenURI 명함 IMAGE URI
     */
    function mintBusinessCard(string memory tokenURI) public payable isBusinessCardInfoRegistered nonReentrant{
        if (_checkAmountOfTokenMint[msg.sender] >= 1)
            require(msg.value == MINT_PRICE, "Check Mint Price");
        
        for (uint i = 0; i < MINT_AMOUNTS; i++) {
            _tokenIds.increment();
            uint newTokenId = _tokenIds.current();
            // ERC721 Contract : _mint 함수에는 address _to, uint256 tokenId을 매개변수로 받고 있음
            _mint(msg.sender, newTokenId);
            // ERC721URIStorage Contract : _setTokenURI에는 uint256 tokenId, string tokenURI를 매개변수로 받고 있음
            _setTokenURI(newTokenId, tokenURI);

            // mapping 업데이트
            uint[] storage tokenIdsMadeByIssuer = _tokenIdsMadeByIssuer[msg.sender];
            tokenIdsMadeByIssuer.push(newTokenId);
            _isTokenOwnedByIssuer[msg.sender][newTokenId] = true;

            emit BusinessCardMinted(newTokenId, msg.sender, _amountOfTokenOwnedByIssuer[msg.sender]);
        }

        _checkAmountOfTokenMint[msg.sender]++;
        _amountOfTokenOwnedByIssuer[msg.sender] = _amountOfTokenOwnedByIssuer[msg.sender] + MINT_AMOUNTS;
    }

    /**
     * @dev BusinessCard를 전송하는 함수
     * @param _to 명함 전송할 주소
     * @param _lat 명함 전송한 위도
     * @param _lng 명함 전송한 경도
     */
    function transferBusinessCard(address _to, string memory _lat, string memory _lng) public isBusinessCardInfoRegistered {
        require(_amountOfTokenOwnedByIssuer[msg.sender] != 0, "Mint your business card First");
        require(_checkAmountOfTokenOwnedExceptIssuer[_to] < MAX_BUSINESS_CARD, "Already have business card");

        uint tokenIdToTransfer;
        uint[] memory tokenIdsMadeByIssuer = _tokenIdsMadeByIssuer[msg.sender];
        BusinessCardTransferLocation memory bcTransferLocation = BusinessCardTransferLocation({
            lat: _lat,
            lng: _lng
        });
        
        // issuer가 만든 tokenId 배열에 담아서 반복문을 사용하여 issuer가 소유한 tokenId를 찾음
        // true인 tokenId가 있다면 반복문 종료
        for (uint i = 0; i < tokenIdsMadeByIssuer.length; i++) {
            uint tokenId = tokenIdsMadeByIssuer[i];
            if (_isTokenOwnedByIssuer[msg.sender][tokenId] == true) {
                tokenIdToTransfer = tokenId;
                break;
            }
            // 만약 i가 tokenIdsMadeByIssuer.length - 1이고 tokenId를 소유하지 않았다면 에러 발생
            if ((i == tokenIdsMadeByIssuer.length - 1) && (_isTokenOwnedByIssuer[msg.sender][tokenId] == false)){
                revert No_Business_Card_To_Transfer();
            }
        }
        // ERC721 Contract : safeTransferFrom에는 address from, address to, uint256 tokenId를 매개변수로 받고 있음
        safeTransferFrom(msg.sender, _to, tokenIdToTransfer);

        // mapping 업데이트
        _tokenIdTransferLocation[tokenIdToTransfer] = bcTransferLocation;
        _isTokenOwnedByIssuer[msg.sender][tokenIdToTransfer]= false;
        _amountOfTokenOwnedByIssuer[msg.sender]--;
        _checkAmountOfTokenOwnedExceptIssuer[_to]++;

        emit BusinessCardTransfered(_to, msg.sender, tokenIdToTransfer, _amountOfTokenOwnedByIssuer[msg.sender]);
    }

    /**
     * @dev 명함 정보 얻는 view 함수
     * @param issuer 명함 민팅한 주소
     */
    function getBusinessCardInfo(address issuer) external view returns(BusinessCardInfo memory){
        return _bcInfo[issuer];
    }

    /**
     * @dev 가지고 있는 명함 갯수 확인하는 view 함수
     * @param issuer 명함 민팅한 주소
     */
    function getAmountOfTokenOwnedByIssuer(address issuer) external view returns(uint){
        return _amountOfTokenOwnedByIssuer[issuer];
    }

    /**
     * @dev 명함 위치 정보 얻는 view 함수
     * @param tokenId 명함 토큰 아이디
     */
    function getBusinessCardLocation(uint tokenId) external view returns(BusinessCardTransferLocation memory){
        return _tokenIdTransferLocation[tokenId];
    }
}