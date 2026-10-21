@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Location'
define view entity ZI_LOCATION
  as select from zrap_location
{
  key location_id   as LocationID,
      @Semantics.text: true
      location_name as LocationName,
      city          as City,
      country_code  as CountryCode,
      is_active     as IsActive
}
