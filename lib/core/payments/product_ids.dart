class ProductIds {
  const ProductIds._();

  static const weekly = String.fromEnvironment(
    'CHRONIKA_WEEKLY_PRODUCT_ID',
    defaultValue: 'chronnika_premium_weekly',
  );
  static const yearly = String.fromEnvironment(
    'CHRONIKA_YEARLY_PRODUCT_ID',
    defaultValue: 'chronnika_premium_yearly',
  );
}
