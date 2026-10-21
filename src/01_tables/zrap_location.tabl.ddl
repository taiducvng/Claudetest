@EndUserText.label : 'Location Master'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zrap_location {
  key client      : abap.clnt not null;
  key location_id : abap.char(8) not null;
  location_name   : abap.char(80);
  city            : abap.char(40);
  country_code    : abap.char(3);
  is_active       : abap_boolean;
}
