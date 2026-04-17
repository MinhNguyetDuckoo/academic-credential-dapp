// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CredentialRegistry
 * @dev Lưu trữ và xác thực chứng chỉ học thuật trên Blockchain
 */
contract CredentialRegistry is Ownable {

    // ─── Struct ────────────────────────────────────────────────
    struct Credential {
        bytes32  credentialHash;   // Hash của nội dung chứng chỉ
        address  issuer;           // Địa chỉ trường cấp bằng
        string   studentName;      // Tên sinh viên
        string   courseName;       // Tên khóa học / bằng cấp
        uint256  issueDate;        // Timestamp cấp bằng
        bool     isRevoked;        // Đã thu hồi chưa?
    }

    // ─── State Variables ───────────────────────────────────────
    // credentialId => Credential
    mapping(bytes32 => Credential) private credentials;

    // Địa chỉ được phép cấp chứng chỉ (trường học)
    mapping(address => bool) public authorizedIssuers;

    // ─── Events ────────────────────────────────────────────────
    event CredentialIssued(
        bytes32 indexed credentialId,
        address indexed issuer,
        string  studentName,
        string  courseName,
        uint256 issueDate
    );
    event CredentialRevoked(bytes32 indexed credentialId);
    event IssuerAuthorized(address indexed issuer);
    event IssuerRevoked(address indexed issuer);

    // ─── Modifiers ─────────────────────────────────────────────
    modifier onlyAuthorizedIssuer() {
        require(authorizedIssuers[msg.sender], "Khong co quyen cap chung chi");
        _;
    }

    modifier credentialExists(bytes32 credentialId) {
        require(credentials[credentialId].issueDate != 0, "Chung chi khong ton tai");
        _;
    }

    // ─── Constructor ───────────────────────────────────────────
    constructor() Ownable(msg.sender) {
        // Chủ hợp đồng (deployer) tự động được cấp quyền issuer
        authorizedIssuers[msg.sender] = true;
    }

    // ─── Admin Functions ───────────────────────────────────────

    /// @notice Owner thêm trường học được cấp chứng chỉ
    function authorizeIssuer(address issuer) external onlyOwner {
        authorizedIssuers[issuer] = true;
        emit IssuerAuthorized(issuer);
    }

    /// @notice Owner thu hồi quyền của trường học
    function revokeIssuer(address issuer) external onlyOwner {
        authorizedIssuers[issuer] = false;
        emit IssuerRevoked(issuer);
    }

    // ─── Core Functions ────────────────────────────────────────

    /**
     * @notice Cấp chứng chỉ mới
     * @param studentName   Tên sinh viên
     * @param courseName    Tên khóa học
     * @param credentialHash Hash của file chứng chỉ gốc (PDF, JSON...)
     * @return credentialId  ID duy nhất của chứng chỉ
     */
    function issueCredential(
        string  memory studentName,
        string  memory courseName,
        bytes32        credentialHash
    ) external onlyAuthorizedIssuer returns (bytes32 credentialId) {

        // Tạo ID duy nhất từ hash + issuer + timestamp
        credentialId = keccak256(
            abi.encodePacked(credentialHash, msg.sender, block.timestamp)
        );

        require(credentials[credentialId].issueDate == 0, "Chung chi da ton tai");

        credentials[credentialId] = Credential({
            credentialHash: credentialHash,
            issuer:         msg.sender,
            studentName:    studentName,
            courseName:     courseName,
            issueDate:      block.timestamp,
            isRevoked:      false
        });

        emit CredentialIssued(credentialId, msg.sender, studentName, courseName, block.timestamp);
    }

    /**
     * @notice Thu hồi chứng chỉ (khi có sai sót)
     */
    function revokeCredential(bytes32 credentialId)
        external
        onlyAuthorizedIssuer
        credentialExists(credentialId)
    {
        Credential storage cred = credentials[credentialId];
        require(cred.issuer == msg.sender, "Chi issuer goc moi co quyen thu hoi");
        require(!cred.isRevoked, "Chung chi da bi thu hoi truoc do");

        cred.isRevoked = true;
        emit CredentialRevoked(credentialId);
    }

    /**
     * @notice Xác thực chứng chỉ — ai cũng có thể gọi (view)
     * @return isValid    true nếu hợp lệ và chưa bị thu hồi
     * @return credential Toàn bộ thông tin chứng chỉ
     */
    function verifyCredential(bytes32 credentialId)
        external
        view
        credentialExists(credentialId)
        returns (bool isValid, Credential memory credential)
    {
        credential = credentials[credentialId];
        isValid = !credential.isRevoked;
    }

    /**
     * @notice Tiện ích: tính hash từ chuỗi văn bản (dùng ở frontend)
     */
    function hashCredentialData(string memory data) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(data));
    }
}