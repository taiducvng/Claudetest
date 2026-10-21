@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Assigned Physical Asset'
define view entity ZI_ASSET_ASSIGNMENT
  as select from zrap_asset_asgn
  association to parent ZI_ASSET_LOAN_ITEM    as _Item             on $projection.ItemUUID = _Item.ItemUUID
  association [1..1] to ZI_ASSET_LOAN_REQUEST as _Request          on $projection.RequestUUID = _Request.RequestUUID
  association [0..1] to ZI_ASSET_MASTER       as _Asset            on $projection.AssetUUID = _Asset.AssetUUID
  association [0..1] to ZI_ASGN_STATUS_VH     as _AssignmentStatus on $projection.AssignmentStatus = _AssignmentStatus.AssignmentStatus
  association [0..1] to ZI_RETURN_CONDITION_VH as _ReturnCondition on $projection.ReturnCondition = _ReturnCondition.ConditionCode
{
  key assignment_uuid       as AssignmentUUID,
      request_uuid          as RequestUUID,
      item_uuid             as ItemUUID,
      asset_uuid            as AssetUUID,
      assigned_by           as AssignedBy,
      assigned_at           as AssignedAt,
      checkout_date         as CheckoutDate,
      return_date           as ReturnDate,
      return_condition      as ReturnCondition,
      return_note           as ReturnNote,
      assignment_status     as AssignmentStatus,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Item,
      _Request,
      _Asset,
      _AssignmentStatus,
      _ReturnCondition
}
