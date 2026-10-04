// User roles in Hyperfeeds
enum UserRole {
  customer,
  admin,
  ceo,
  mainManager,
  branchManager,
  customerService,
  animalHealthExpert,
  unknown;

  static UserRole fromString(String role) {
    switch (role.toUpperCase()) {
      case 'CUSTOMER':
        return UserRole.customer;
      case 'CEO':
        return UserRole.ceo;
      case 'ADMIN':
        return UserRole.admin;
      case 'MAINMANAGER':
      case 'MAIN_MANAGER':
        return UserRole.mainManager;
      case 'BRANCHMANAGER':
      case 'BRANCH_MANAGER':
        return UserRole.branchManager;
      case 'CUSTOMERSERVICE':
      case 'CUSTOMER_SERVICE':
        return UserRole.customerService;
      case 'ANIMALHEALTHEXPERT':
      case 'ANIMAL_HEALTH_EXPERT':
        return UserRole.animalHealthExpert;
      default:
        return UserRole.unknown;
    }
  }

  String toJson() => switch (this) {
    UserRole.mainManager => 'MAIN_MANAGER',
    UserRole.branchManager => 'BRANCH_MANAGER',
    UserRole.customerService => 'CUSTOMER_SERVICE',
    UserRole.animalHealthExpert => 'ANIMAL_HEALTH_EXPERT',
    _ => name.toUpperCase(),
  };
}

class CustomerProfile {
  final String id;
  final String phoneNumber;
  final String? email;
  final String firstName;
  final String lastName;
  final bool phoneVerified;
  final String? preferredBranchId;
  final List<String> roles;

  CustomerProfile({
    required this.id,
    required this.phoneNumber,
    this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneVerified,
    this.preferredBranchId,
    required this.roles,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id']?.toString() ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      email: json['email'],
      firstName: json['firstName'] ?? json['first_name'] ?? '',
      lastName: json['lastName'] ?? json['last_name'] ?? '',
      phoneVerified: json['phoneVerified'] ?? json['phone_verified'] ?? false,
      preferredBranchId:
          json['preferredBranchId']?.toString() ??
          json['preferred_branch_id']?.toString(),
      roles: (json['roles'] as List? ?? const [])
          .map((role) => role.toString())
          .toList(),
    );
  }
}

// Authentication Token response
class AuthTokenResult {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime accessTokenExpiresAt;
  final int refreshTokenExpiresInSeconds;

  AuthTokenResult({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresInSeconds,
  });

  factory AuthTokenResult.fromJson(Map<String, dynamic> json) {
    return AuthTokenResult(
      accessToken: json['accessToken'] ?? json['access_token'] ?? '',
      refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
      tokenType: json['tokenType'] ?? json['token_type'] ?? 'Bearer',
      accessTokenExpiresAt: DateTime.parse(
        json['accessTokenExpiresAt'] ??
            json['access_token_expires_at'] ??
            DateTime.now().toIso8601String(),
      ),
      refreshTokenExpiresInSeconds:
          json['refreshTokenExpiresInSeconds'] ??
          json['refresh_token_expires_in_seconds'] ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': tokenType,
    'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
    'refreshTokenExpiresInSeconds': refreshTokenExpiresInSeconds,
  };
}

// Branch Model
class Branch {
  final String id;
  final String code;
  final String name;
  final String address;
  final String phoneNumber;
  final String? whatsappNumber;
  final String? openingHours;
  final bool collectionEnabled;
  final bool active;

  Branch({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.phoneNumber,
    this.whatsappNumber,
    this.openingHours,
    required this.collectionEnabled,
    required this.active,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      whatsappNumber: json['whatsappNumber'] ?? json['whatsapp_number'],
      openingHours: json['openingHours'] ?? json['opening_hours'],
      collectionEnabled:
          json['collectionEnabled'] ?? json['collection_enabled'] ?? false,
      active: json['active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'address': address,
    'phoneNumber': phoneNumber,
    'whatsappNumber': whatsappNumber,
    'openingHours': openingHours,
    'collectionEnabled': collectionEnabled,
    'active': active,
  };
}

// Category Model
class Category {
  final String id;
  final String name;
  final String? description;
  final bool active;

  Category({
    required this.id,
    required this.name,
    this.description,
    required this.active,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      active: json['active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'active': active,
  };
}

// Product Model
class Product {
  final String id;
  final String sku;
  final String? barcode;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final String packSize;
  final String? imageUrl;
  final bool published;
  final bool active;
  final double? amount;
  final String? currency;
  final double? onHand;
  final double? reserved;
  final double? available;

  Product({
    required this.id,
    required this.sku,
    this.barcode,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.packSize,
    this.imageUrl,
    required this.published,
    required this.active,
    this.amount,
    this.currency,
    this.onHand,
    this.reserved,
    this.available,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      sku: json['sku'] ?? '',
      barcode: json['barcode'],
      categoryId: json['categoryId'] ?? json['category_id'] ?? '',
      categoryName: json['categoryName'] ?? json['category_name'],
      name: json['name'] ?? '',
      description: json['description'],
      packSize: json['packSize'] ?? json['pack_size'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      published: json['published'] ?? false,
      active: json['active'] ?? false,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'],
      onHand:
          (json['onHand'] as num?)?.toDouble() ??
          (json['on_hand'] as num?)?.toDouble(),
      reserved: (json['reserved'] as num?)?.toDouble(),
      available: (json['available'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'barcode': barcode,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'name': name,
    'description': description,
    'packSize': packSize,
    'imageUrl': imageUrl,
    'published': published,
    'active': active,
    'amount': amount,
    'currency': currency,
    'onHand': onHand,
    'reserved': reserved,
    'available': available,
  };
}

// Chick Batch Availability
class ChickBatch {
  final String id;
  final String branchId;
  final String chickType;
  final String breed;
  final DateTime cutoffAt;
  final String deliveryDate;
  final double pricePerChick;
  final String currency;
  final bool depositRequired;
  final double depositPercentage;

  ChickBatch({
    required this.id,
    required this.branchId,
    required this.chickType,
    required this.breed,
    required this.cutoffAt,
    required this.deliveryDate,
    required this.pricePerChick,
    required this.currency,
    required this.depositRequired,
    required this.depositPercentage,
  });

  factory ChickBatch.fromJson(Map<String, dynamic> json) {
    return ChickBatch(
      id: json['id'] ?? '',
      branchId: json['branchId'] ?? json['branch_id'] ?? '',
      chickType: json['chickType'] ?? json['chick_type'] ?? '',
      breed: json['breed'] ?? '',
      cutoffAt: DateTime.parse(
        json['cutoffAt'] ??
            json['cutoff_at'] ??
            DateTime.now().toIso8601String(),
      ),
      deliveryDate: json['deliveryDate'] ?? json['delivery_date'] ?? '',
      pricePerChick:
          (json['pricePerChick'] as num?)?.toDouble() ??
          (json['price_per_chick'] as num?)?.toDouble() ??
          0.0,
      currency: json['currency'] ?? 'USD',
      depositRequired:
          json['depositRequired'] ?? json['deposit_required'] ?? false,
      depositPercentage:
          (json['depositPercentage'] as num?)?.toDouble() ??
          (json['deposit_percentage'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'chickType': chickType,
    'breed': breed,
    'cutoffAt': cutoffAt.toIso8601String(),
    'deliveryDate': deliveryDate,
    'pricePerChick': pricePerChick,
    'currency': currency,
    'depositRequired': depositRequired,
    'depositPercentage': depositPercentage,
  };
}

// Chick Booking Model
class ChickBooking {
  final String id;
  final String reference;
  final String batchId;
  final int quantity;
  final String status; // ORDERED, CONFIRMED, CANCELLED
  final String branchId;
  final String chickType;
  final String breed;
  final double unitPrice;
  final double totalAmount;
  final String currency;
  final DateTime cutoffAt;
  final String deliveryDate;
  final DateTime? createdAt;

  ChickBooking({
    required this.id,
    required this.reference,
    required this.batchId,
    required this.quantity,
    required this.status,
    required this.branchId,
    required this.chickType,
    required this.breed,
    required this.unitPrice,
    required this.totalAmount,
    required this.currency,
    required this.cutoffAt,
    required this.deliveryDate,
    this.createdAt,
  });

  factory ChickBooking.fromJson(Map<String, dynamic> json) {
    return ChickBooking(
      id: json['id'] ?? '',
      reference: json['reference'] ?? '',
      batchId: json['batchId'] ?? json['batch_id'] ?? '',
      quantity: json['quantity'] ?? 0,
      status: json['status'] ?? 'ORDERED',
      branchId: json['branchId'] ?? json['branch_id'] ?? '',
      chickType: json['chickType'] ?? json['chick_type'] ?? '',
      breed: json['breed'] ?? '',
      unitPrice:
          (json['unitPrice'] as num?)?.toDouble() ??
          (json['unit_price'] as num?)?.toDouble() ??
          0,
      totalAmount:
          (json['totalAmount'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble() ??
          0,
      currency: json['currency'] ?? 'USD',
      cutoffAt: DateTime.parse(
        json['cutoffAt'] ??
            json['cutoff_at'] ??
            DateTime.now().toIso8601String(),
      ),
      deliveryDate: json['deliveryDate'] ?? json['delivery_date'] ?? '',
      createdAt: (json['createdAt'] ?? json['created_at']) != null
          ? DateTime.parse(json['createdAt'] ?? json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'batchId': batchId,
    'quantity': quantity,
    'status': status,
    'branchId': branchId,
    'chickType': chickType,
    'breed': breed,
    'unitPrice': unitPrice,
    'totalAmount': totalAmount,
    'currency': currency,
    'cutoffAt': cutoffAt.toIso8601String(),
    'deliveryDate': deliveryDate,
    'created_at': createdAt?.toIso8601String(),
  };
}

// Content Announcement
class Announcement {
  final String id;
  final String title;
  final String body;
  final String? branchId;
  final DateTime publishedFrom;
  final DateTime? publishedUntil;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.branchId,
    required this.publishedFrom,
    this.publishedUntil,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      branchId: json['branchId'] ?? json['branch_id'],
      publishedFrom: DateTime.parse(
        json['publishedFrom'] ??
            json['published_from'] ??
            DateTime.now().toIso8601String(),
      ),
      publishedUntil:
          json['publishedUntil'] != null || json['published_until'] != null
          ? DateTime.parse(json['publishedUntil'] ?? json['published_until'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'branchId': branchId,
    'publishedFrom': publishedFrom.toIso8601String(),
    'publishedUntil': publishedUntil?.toIso8601String(),
  };
}

// Content Special
class Special {
  final String id;
  final String productId;
  final String name;
  final String? branchId;
  final double promotionalPrice;
  final String currency;
  final DateTime startsAt;
  final DateTime endsAt;

  Special({
    required this.id,
    required this.productId,
    required this.name,
    this.branchId,
    required this.promotionalPrice,
    required this.currency,
    required this.startsAt,
    required this.endsAt,
  });

  factory Special.fromJson(Map<String, dynamic> json) {
    return Special(
      id: json['id'] ?? '',
      productId: json['productId'] ?? json['product_id'] ?? '',
      name: json['name'] ?? '',
      branchId: json['branchId'] ?? json['branch_id'],
      promotionalPrice:
          (json['promotionalPrice'] as num?)?.toDouble() ??
          (json['promotional_price'] as num?)?.toDouble() ??
          0.0,
      currency: json['currency'] ?? 'USD',
      startsAt: DateTime.parse(
        json['startsAt'] ??
            json['starts_at'] ??
            DateTime.now().toIso8601String(),
      ),
      endsAt: DateTime.parse(
        json['endsAt'] ?? json['ends_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'branchId': branchId,
    'promotionalPrice': promotionalPrice,
    'currency': currency,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
  };
}

// Notification Inbox Item
class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'INFO',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'])
          : null,
      readAt: json['readAt'] != null || json['read_at'] != null
          ? DateTime.parse(json['readAt'] ?? json['read_at'])
          : null,
      createdAt: DateTime.parse(
        json['createdAt'] ??
            json['created_at'] ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'data': data,
    'readAt': readAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}

// Livestock Question Model
class LivestockQuestion {
  final String id;
  final String subject;
  final String question;
  final String status; // AWAITING_EXPERT, ANSWERED
  final String? aiDraft;
  final String? expertAnswer;
  final DateTime createdAt;
  final DateTime? answeredAt;

  LivestockQuestion({
    required this.id,
    required this.subject,
    required this.question,
    required this.status,
    this.aiDraft,
    this.expertAnswer,
    required this.createdAt,
    this.answeredAt,
  });

  factory LivestockQuestion.fromJson(Map<String, dynamic> json) {
    return LivestockQuestion(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      question: json['question'] ?? '',
      status: json['status'] ?? 'AWAITING_EXPERT',
      aiDraft: json['aiDraft'] ?? json['ai_draft'],
      expertAnswer: json['expertAnswer'] ?? json['expert_answer'],
      createdAt: DateTime.parse(
        json['createdAt'] ??
            json['created_at'] ??
            DateTime.now().toIso8601String(),
      ),
      answeredAt: json['answeredAt'] != null || json['answered_at'] != null
          ? DateTime.parse(json['answeredAt'] ?? json['answered_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'question': question,
    'status': status,
    'aiDraft': aiDraft,
    'expertAnswer': expertAnswer,
    'createdAt': createdAt.toIso8601String(),
    'answeredAt': answeredAt?.toIso8601String(),
  };
}

// Shopping Cart Item
class CartItem {
  final String productId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final String branchId;

  CartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.branchId,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] ?? json['product_id'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice:
          (json['unitPrice'] as num?)?.toDouble() ??
          (json['unit_price'] as num?)?.toDouble() ??
          0.0,
      lineTotal:
          (json['lineTotal'] as num?)?.toDouble() ??
          (json['line_total'] as num?)?.toDouble() ??
          0.0,
      branchId: json['branchId'] ?? json['branch_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,
    'line_total': lineTotal,
    'branch_id': branchId,
  };
}

// Checkout Response
class CheckoutResult {
  final String orderId;
  final String reference;
  final double total;
  final String currency;
  final String paynowReference;
  final String instructions;

  CheckoutResult({
    required this.orderId,
    required this.reference,
    required this.total,
    required this.currency,
    required this.paynowReference,
    required this.instructions,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      orderId: json['orderId'] ?? json['order_id'] ?? '',
      reference: json['reference'] ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      paynowReference:
          json['paynowReference'] ?? json['paynow_reference'] ?? '',
      instructions: json['instructions'] ?? '',
    );
  }
}

// Customer Order
class Order {
  final String id;
  final String reference;
  final String branchId;
  final String status;
  final double total;
  final String currency;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.reference,
    required this.branchId,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      reference: json['reference'] ?? '',
      branchId: json['branchId'] ?? json['branch_id'] ?? '',
      status: json['status'] ?? 'PAYMENT_PENDING',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      createdAt: DateTime.parse(
        json['createdAt'] ??
            json['created_at'] ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'branch_id': branchId,
    'status': status,
    'total': total,
    'currency': currency,
    'created_at': createdAt.toIso8601String(),
  };
}
