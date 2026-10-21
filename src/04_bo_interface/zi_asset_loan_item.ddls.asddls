@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Asset Loan Request Item'
define view entity ZI_ASSET_LOAN_ITEM
  as select from zrap_asset_req_i
  association to parent ZI_ASSET_LOAN_REQUEST as _Request    on $projection.RequestUUID = _Request.RequestUUID
  composition [0..*] of ZI_ASSET_ASSIGNMENT   as _Assignments
  association [0..1] to ZI_ASSET_CATEGORY     as _Category   on $projection.CategoryID = _Category.CategoryID
  association [0..1] to ZI_ITEM_STATUS_VH     as _ItemStatus on $projection.ItemStatus = _ItemStatus.ItemStatus
{
  key item_uuid             as ItemUUID,
      request_uuid          as RequestUUID,
      item_number           as ItemNumber,
      category_id           as CategoryID,
      requested_quantity    as RequestedQuantity,
      approved_quantity     as ApprovedQuantity,
      special_requirement   as SpecialRequirement,
      item_status           as ItemStatus,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Request,
      _Assignments,
      _Category,
      _ItemStatus
}
