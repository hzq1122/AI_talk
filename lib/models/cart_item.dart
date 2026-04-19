class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? shop;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.shop,
  });

  CartItem copyWith({int? quantity}) => CartItem(
        id: id,
        name: name,
        price: price,
        quantity: quantity ?? this.quantity,
        shop: shop,
      );

  double get total => price * quantity;

  Map<String, dynamic> toDbRow() => {
        'id': id,
        'name': name,
        'price': price,
        'quantity': quantity,
        'shop': shop,
      };

  factory CartItem.fromDbRow(Map<String, dynamic> row) => CartItem(
        id: row['id'] as String,
        name: row['name'] as String,
        price: (row['price'] as num).toDouble(),
        quantity: row['quantity'] as int? ?? 1,
        shop: row['shop'] as String?,
      );
}
