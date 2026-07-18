/// Which bills a report covers: all, only GST (tax invoice) bills, or only
/// plain (non-GST) bills. Lets the owner produce separate GST / non-GST reports.
enum GstFilter {
  all,
  gst,
  nonGst;

  String get label => switch (this) {
        GstFilter.all => 'All bills',
        GstFilter.gst => 'With GST',
        GstFilter.nonGst => 'Without GST',
      };

  /// The `is_gst` value to filter on, or null for "all".
  bool? get isGstValue => switch (this) {
        GstFilter.all => null,
        GstFilter.gst => true,
        GstFilter.nonGst => false,
      };
}
