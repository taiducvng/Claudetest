@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Physical Asset Master'
define view entity ZI_ASSET_MASTER
  as select from zrap_asset_mst
  association [0..1] to ZI_ASSET_CATEGORY as _Category on $projection.CategoryID = _Category.CategoryID
  association [0..1] to ZI_LOCATION       as _Location on $projection.LocationID = _Location.LocationID
{
  key asset_uuid     as AssetUUID,
      asset_id       as AssetID,
      category_id    as CategoryID,
      @Semantics.text: true
      asset_name     as AssetName,
      brand          as Brand,
      model          as Model,
      serial_number  as SerialNumber,
      location_id    as LocationID,
      asset_status   as AssetStatus,
      condition_code as ConditionCode,
      purchase_date  as PurchaseDate,
      is_active      as IsActive,
      _Category,
      _Location
}
