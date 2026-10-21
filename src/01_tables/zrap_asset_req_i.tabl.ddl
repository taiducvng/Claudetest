@EndUserText.label : 'Requested Asset Item'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_asset_req_i {
  key client            : abap.clnt not null;
  key item_uuid         : sysuuid_x16 not null;
  request_uuid          : sysuuid_x16;
  item_number           : abap.numc(3);
  category_id           : abap.char(6);
  requested_quantity    : abap.int2;
  approved_quantity     : abap.int2;
  special_requirement   : abap.char(255);
  item_status           : abap.char(2);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  local_last_changed_at : abp_lastchange_tstmpl;
}
