@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Location Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_LOCATION_VH
  as select from ZI_LOCATION
{
      @ObjectModel.text.element: ['LocationName']
      @Search.defaultSearchElement: true
  key LocationID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      LocationName,
      @Search.defaultSearchElement: true
      City,
      CountryCode
}
where
  IsActive = 'X'
