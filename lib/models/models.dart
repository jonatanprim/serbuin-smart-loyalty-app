import 'dart:convert';

enum UserRole { customer, merchant }

class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? phone;
  final String? avatarUrl;
  final bool isProfileComplete;
  final DateTime createdAt;
  final MerchantProfile? merchantProfile;
  final CustomerProfile? customerProfile;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.avatarUrl,
    this.isProfileComplete = false,
    DateTime? createdAt,
    this.merchantProfile,
    this.customerProfile,
  }) : createdAt = createdAt ?? DateTime.now();

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? phone,
    String? avatarUrl,
    bool? isProfileComplete,
    DateTime? createdAt,
    MerchantProfile? merchantProfile,
    CustomerProfile? customerProfile,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      merchantProfile: merchantProfile ?? this.merchantProfile,
      customerProfile: customerProfile ?? this.customerProfile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'isProfileComplete': isProfileComplete,
      'createdAt': createdAt.toIso8601String(),
      'merchantProfile': merchantProfile?.toMap(),
      'customerProfile': customerProfile?.toMap(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] == 'merchant' ? UserRole.merchant : UserRole.customer,
      phone: map['phone'],
      avatarUrl: map['avatarUrl'],
      isProfileComplete: map['isProfileComplete'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      merchantProfile: map['merchantProfile'] != null
          ? MerchantProfile.fromMap(map['merchantProfile'])
          : null,
      customerProfile: map['customerProfile'] != null
          ? CustomerProfile.fromMap(map['customerProfile'])
          : null,
    );
  }
}

class MerchantProfile {
  final String businessName;
  final String category;
  final String address;
  final String phone;
  final String operatingHours;
  final String description;

  MerchantProfile({
    required this.businessName,
    required this.category,
    required this.address,
    required this.phone,
    required this.operatingHours,
    required this.description,
  });

  MerchantProfile copyWith({
    String? businessName,
    String? category,
    String? address,
    String? phone,
    String? operatingHours,
    String? description,
  }) {
    return MerchantProfile(
      businessName: businessName ?? this.businessName,
      category: category ?? this.category,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      operatingHours: operatingHours ?? this.operatingHours,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'category': category,
      'address': address,
      'phone': phone,
      'operatingHours': operatingHours,
      'description': description,
    };
  }

  factory MerchantProfile.fromMap(Map<String, dynamic> map) {
    return MerchantProfile(
      businessName: map['businessName'] ?? '',
      category: map['category'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      operatingHours: map['operatingHours'] ?? '',
      description: map['description'] ?? '',
    );
  }
}

class CustomerProfile {
  final String phone;
  final String birthDate;
  final String bio;
  final String favoriteCategory;

  CustomerProfile({
    required this.phone,
    required this.birthDate,
    required this.bio,
    required this.favoriteCategory,
  });

  CustomerProfile copyWith({
    String? phone,
    String? birthDate,
    String? bio,
    String? favoriteCategory,
  }) {
    return CustomerProfile(
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      bio: bio ?? this.bio,
      favoriteCategory: favoriteCategory ?? this.favoriteCategory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'birthDate': birthDate,
      'bio': bio,
      'favoriteCategory': favoriteCategory,
    };
  }

  factory CustomerProfile.fromMap(Map<String, dynamic> map) {
    return CustomerProfile(
      phone: map['phone'] ?? '',
      birthDate: map['birthDate'] ?? '',
      bio: map['bio'] ?? '',
      favoriteCategory: map['favoriteCategory'] ?? '',
    );
  }
}

class LoyaltyProgram {
  final String id;
  final String merchantId;
  final String merchantName;
  final String title;
  final String description;
  final String category;
  final int totalStamps;
  final String rewardTitle;
  final String rewardDescription;
  final List<String> gradientColors; // Hex codes e.g. ["#6366F1", "#9333EA"]
  final String iconName;
  final bool isActive;
  final DateTime createdAt;
  final int memberCount;

  LoyaltyProgram({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.title,
    required this.description,
    required this.category,
    required this.totalStamps,
    required this.rewardTitle,
    required this.rewardDescription,
    required this.gradientColors,
    required this.iconName,
    this.isActive = true,
    DateTime? createdAt,
    this.memberCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  LoyaltyProgram copyWith({
    String? id,
    String? merchantId,
    String? merchantName,
    String? title,
    String? description,
    String? category,
    int? totalStamps,
    String? rewardTitle,
    String? rewardDescription,
    List<String>? gradientColors,
    String? iconName,
    bool? isActive,
    DateTime? createdAt,
    int? memberCount,
  }) {
    return LoyaltyProgram(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      totalStamps: totalStamps ?? this.totalStamps,
      rewardTitle: rewardTitle ?? this.rewardTitle,
      rewardDescription: rewardDescription ?? this.rewardDescription,
      gradientColors: gradientColors ?? this.gradientColors,
      iconName: iconName ?? this.iconName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'title': title,
      'description': description,
      'category': category,
      'totalStamps': totalStamps,
      'rewardTitle': rewardTitle,
      'rewardDescription': rewardDescription,
      'gradientColors': gradientColors,
      'iconName': iconName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'memberCount': memberCount,
    };
  }

  factory LoyaltyProgram.fromMap(Map<String, dynamic> map) {
    return LoyaltyProgram(
      id: map['id'] ?? '',
      merchantId: map['merchantId'] ?? '',
      merchantName: map['merchantName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      totalStamps: map['totalStamps'] ?? 6,
      rewardTitle: map['rewardTitle'] ?? '',
      rewardDescription: map['rewardDescription'] ?? '',
      gradientColors: List<String>.from(map['gradientColors'] ?? ['#6366F1', '#9333EA']),
      iconName: map['iconName'] ?? 'coffee',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      memberCount: map['memberCount'] ?? 0,
    );
  }
}

class MemberRecord {
  final String id;
  final String programId;
  final String programTitle;
  final String merchantId;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final int stampsCollected;
  final int totalStampsRequired;
  final String status; // 'active', 'completed', 'expired'
  final DateTime lastStampDate;
  final DateTime joinedDate;
  final String riskLevel; // 'low', 'medium', 'high'
  final String riskReason;
  final String recommendedVoucher;
  final String aiInsight;

  MemberRecord({
    required this.id,
    required this.programId,
    required this.programTitle,
    required this.merchantId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.stampsCollected,
    required this.totalStampsRequired,
    required this.status,
    required this.lastStampDate,
    required this.joinedDate,
    required this.riskLevel,
    required this.riskReason,
    required this.recommendedVoucher,
    required this.aiInsight,
  });

  MemberRecord copyWith({
    String? id,
    String? programId,
    String? programTitle,
    String? merchantId,
    String? customerId,
    String? customerName,
    String? customerEmail,
    int? stampsCollected,
    int? totalStampsRequired,
    String? status,
    DateTime? lastStampDate,
    DateTime? joinedDate,
    String? riskLevel,
    String? riskReason,
    String? recommendedVoucher,
    String? aiInsight,
  }) {
    return MemberRecord(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      programTitle: programTitle ?? this.programTitle,
      merchantId: merchantId ?? this.merchantId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      stampsCollected: stampsCollected ?? this.stampsCollected,
      totalStampsRequired: totalStampsRequired ?? this.totalStampsRequired,
      status: status ?? this.status,
      lastStampDate: lastStampDate ?? this.lastStampDate,
      joinedDate: joinedDate ?? this.joinedDate,
      riskLevel: riskLevel ?? this.riskLevel,
      riskReason: riskReason ?? this.riskReason,
      recommendedVoucher: recommendedVoucher ?? this.recommendedVoucher,
      aiInsight: aiInsight ?? this.aiInsight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'programId': programId,
      'programTitle': programTitle,
      'merchantId': merchantId,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'stampsCollected': stampsCollected,
      'totalStampsRequired': totalStampsRequired,
      'status': status,
      'lastStampDate': lastStampDate.toIso8601String(),
      'joinedDate': joinedDate.toIso8601String(),
      'riskLevel': riskLevel,
      'riskReason': riskReason,
      'recommendedVoucher': recommendedVoucher,
      'aiInsight': aiInsight,
    };
  }

  factory MemberRecord.fromMap(Map<String, dynamic> map) {
    return MemberRecord(
      id: map['id'] ?? '',
      programId: map['programId'] ?? '',
      programTitle: map['programTitle'] ?? '',
      merchantId: map['merchantId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      stampsCollected: map['stampsCollected'] ?? 0,
      totalStampsRequired: map['totalStampsRequired'] ?? 6,
      status: map['status'] ?? 'active',
      lastStampDate: map['lastStampDate'] != null
          ? DateTime.parse(map['lastStampDate'])
          : DateTime.now(),
      joinedDate: map['joinedDate'] != null
          ? DateTime.parse(map['joinedDate'])
          : DateTime.now(),
      riskLevel: map['riskLevel'] ?? 'low',
      riskReason: map['riskReason'] ?? '',
      recommendedVoucher: map['recommendedVoucher'] ?? '',
      aiInsight: map['aiInsight'] ?? '',
    );
  }
}

class Voucher {
  final String id;
  final String code;
  final String programId;
  final String merchantId;
  final String merchantName;
  final String customerId;
  final String title;
  final String description;
  final String discountType; // 'free_item', 'percentage', 'amount'
  final String discountValue;
  final DateTime claimedAt;
  final DateTime expiresAt;
  final bool isRedeemed;
  final DateTime? redeemedAt;

  Voucher({
    required this.id,
    required this.code,
    required this.programId,
    required this.merchantId,
    required this.merchantName,
    required this.customerId,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.claimedAt,
    required this.expiresAt,
    this.isRedeemed = false,
    this.redeemedAt,
  });

  Voucher copyWith({
    String? id,
    String? code,
    String? programId,
    String? merchantId,
    String? merchantName,
    String? customerId,
    String? title,
    String? description,
    String? discountType,
    String? discountValue,
    DateTime? claimedAt,
    DateTime? expiresAt,
    bool? isRedeemed,
    DateTime? redeemedAt,
  }) {
    return Voucher(
      id: id ?? this.id,
      code: code ?? this.code,
      programId: programId ?? this.programId,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      customerId: customerId ?? this.customerId,
      title: title ?? this.title,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      claimedAt: claimedAt ?? this.claimedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRedeemed: isRedeemed ?? this.isRedeemed,
      redeemedAt: redeemedAt ?? this.redeemedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'programId': programId,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'customerId': customerId,
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'claimedAt': claimedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isRedeemed': isRedeemed,
      'redeemedAt': redeemedAt?.toIso8601String(),
    };
  }

  factory Voucher.fromMap(Map<String, dynamic> map) {
    return Voucher(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      programId: map['programId'] ?? '',
      merchantId: map['merchantId'] ?? '',
      merchantName: map['merchantName'] ?? '',
      customerId: map['customerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      discountType: map['discountType'] ?? 'free_item',
      discountValue: map['discountValue'] ?? 'Free Item',
      claimedAt: map['claimedAt'] != null
          ? DateTime.parse(map['claimedAt'])
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'])
          : DateTime.now().add(const Duration(days: 30)),
      isRedeemed: map['isRedeemed'] ?? false,
      redeemedAt: map['redeemedAt'] != null
          ? DateTime.parse(map['redeemedAt'])
          : null,
    );
  }
}

class ActivityLog {
  final String id;
  final String userId;
  final String type; // 'stamp_earned', 'voucher_claimed', 'voucher_redeemed', 'program_created'
  final String title;
  final String subtitle;
  final String merchantName;
  final DateTime timestamp;
  final int? stampsCount;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.merchantName,
    DateTime? timestamp,
    this.stampsCount,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'merchantName': merchantName,
      'timestamp': timestamp.toIso8601String(),
      'stampsCount': stampsCount,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'stamp_earned',
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      merchantName: map['merchantName'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      stampsCount: map['stampsCount'],
    );
  }
}
