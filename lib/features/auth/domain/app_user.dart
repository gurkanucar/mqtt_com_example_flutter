/// A user that can sign in. `amir` is the master.
class AppUser {
  const AppUser(this.id, this.isMaster);

  final String id;
  final bool isMaster;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.isMaster == isMaster;

  @override
  int get hashCode => Object.hash(id, isMaster);
}

const List<AppUser> kUsers = [
  AppUser('amir', true),
  AppUser('memur1', false),
  AppUser('memur2', false),
];
