class User {
  int? id;
  String name;
  String username;
  String password;
  String dateCreated;
  String dateUpdated;

  User({
    this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.dateCreated,
    required this.dateUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password': password,
      'date_created': dateCreated,
      'date_updated': dateUpdated,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      username: map['username'],
      password: map['password'],
      dateCreated: map['date_created'],
      dateUpdated: map['date_updated'],
    );
  }
}