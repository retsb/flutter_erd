/// Lightweight data carried by ERD links.
///
/// Contains the originating column name and the referenced column names
/// for the foreign-key connection. Kept intentionally small to be serializable
/// on the link objects used by the diagram controller.
class ERDLinkData {
  /// The column name on the source table that the link represents.
  final String columnName;

  /// The referenced column names on the target table.
  final List<String> referenceColumns;

  ERDLinkData({required this.columnName, required this.referenceColumns});
}
