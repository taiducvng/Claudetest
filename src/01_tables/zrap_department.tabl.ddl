@EndUserText.label : 'Department Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_department {
  key client      : abap.clnt not null;
  key department_id : abap.char(8) not null;
  department_name : abap.char(80);
  manager_id      : abap.char(12);
  is_active       : abap_boolean;
}
