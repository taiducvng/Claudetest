@EndUserText.label : 'Asset Loan Request Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_asset_req_h {
  key client            : abap.clnt not null;
  key request_uuid      : sysuuid_x16 not null;
  request_id            : abap.char(10);
  requester_id          : abap.char(12);
  department_id         : abap.char(8);
  location_id           : abap.char(8);
  request_date          : abap.dats;
  needed_from_date      : abap.dats;
  expected_return_date  : abap.dats;
  purpose               : abap.char(255);
  status                : abap.char(2);
  approver_id           : abap.char(12);
  rejection_reason      : abap.char(255);
  correction_reason     : abap.char(255);
  checkout_date         : abap.dats;
  completion_date       : abap.dats;
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  local_last_changed_at : abp_lastchange_tstmpl;
}
