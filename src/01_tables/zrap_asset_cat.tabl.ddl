@EndUserText.label : 'Asset Category'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_asset_cat {
  key client        : abap.clnt not null;
  key category_id   : abap.char(6) not null;
  category_name     : abap.char(60);
  max_loan_days     : abap.int2;
  approval_required : abap_boolean;
  priority          : abap.int1;
  is_active         : abap_boolean;
}
