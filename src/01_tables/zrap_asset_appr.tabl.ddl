@EndUserText.label : 'Approval Configuration'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_asset_appr {
  key client        : abap.clnt not null;
  key department_id : abap.char(8) not null;
  key category_id   : abap.char(6) not null;
  approver_id       : abap.char(12);
  approver_name     : abap.char(80);
  is_active         : abap_boolean;
}
