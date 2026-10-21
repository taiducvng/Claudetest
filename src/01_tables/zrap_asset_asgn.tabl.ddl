// NOTE: Excel names this table ZRAP_ASSET_ASSIGN (17 chars).
// DDIC table names are limited to 16 chars, so it is shortened to ZRAP_ASSET_ASGN.
@EndUserText.label : 'Assigned Physical Asset'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_asset_asgn {
  key client            : abap.clnt not null;
  key assignment_uuid   : sysuuid_x16 not null;
  request_uuid          : sysuuid_x16;
  item_uuid             : sysuuid_x16;
  asset_uuid            : sysuuid_x16;
  assigned_by           : abap.char(12);
  assigned_at           : abp_creation_tstmpl;
  checkout_date         : abap.dats;
  return_date           : abap.dats;
  return_condition      : abap.char(2);
  return_note           : abap.char(255);
  assignment_status     : abap.char(2);
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  local_last_changed_at : abp_lastchange_tstmpl;
}
