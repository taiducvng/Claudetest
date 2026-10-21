@EndUserText.label : 'User Department Mapping'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_user_dept {
  key client      : abap.clnt not null;
  key user_id     : abap.char(12) not null;
  department_id   : abap.char(8);
  is_active       : abap_boolean;
}
