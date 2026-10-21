@EndUserText.label: 'Assign Asset - Parameter'
define abstract entity ZA_ASSET_ASSIGN_PARAM
{
  // CategoryID / LocationID are pre-filled from the item and used only
  // to filter the asset value help (VH-004 dependent help).
  @EndUserText.label: 'Category'
  @UI.defaultValue: #( 'ELEMENT_OF_REFERENCED_ENTITY: CategoryID' )
  CategoryID : abap.char(6);
  @EndUserText.label: 'Location'
  @UI.defaultValue: #( 'ELEMENT_OF_REFERENCED_ENTITY: RequestLocationID' )
  LocationID : abap.char(8);
  // Excel uses AssetUUID; the business key AssetID is easier for users.
  @EndUserText.label: 'Asset ID'
  @Consumption.valueHelpDefinition: [{
      entity: { name: 'ZI_AVAILABLE_ASSET_VH', element: 'AssetID' },
      additionalBinding: [ { localElement: 'CategoryID', element: 'CategoryID', usage: #FILTER },
                           { localElement: 'LocationID', element: 'LocationID', usage: #FILTER } ] }]
  AssetID    : abap.char(12);
}
