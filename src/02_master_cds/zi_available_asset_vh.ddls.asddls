@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Available Asset Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_AVAILABLE_ASSET_VH
  as select from ZI_ASSET_MASTER
{
      @UI.hidden: true
  key AssetUUID,
      @ObjectModel.text.element: ['AssetName']
      @Search.defaultSearchElement: true
      AssetID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      AssetName,
      Brand,
      Model,
      @Search.defaultSearchElement: true
      SerialNumber,
      CategoryID,
      LocationID
}
where
      AssetStatus = '01'
  and IsActive    = 'X'
