@EndUserText.label : 'Physical Asset Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_asset_mst {
  key client            : abap.clnt not null;
  key asset_uuid        : sysuuid_x16 not null;
  asset_id              : abap.char(12);
  category_id           : abap.char(6);
  asset_name            : abap.char(80);
  brand                 : abap.char(40);
  model                 : abap.char(40);
  serial_number         : abap.char(40);
  location_id           : abap.char(8);
  asset_status          : abap.char(2);
  condition_code        : abap.char(2);
  purchase_date         : abap.dats;
  is_active             : abap_boolean;
  local_last_changed_at : abp_lastchange_tstmpl;
}
