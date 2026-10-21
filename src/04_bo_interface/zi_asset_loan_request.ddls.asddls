@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Asset Loan Request (Root)'
define root view entity ZI_ASSET_LOAN_REQUEST
  as select from zrap_asset_req_h
  composition [0..*] of ZI_ASSET_LOAN_ITEM    as _Items
  association [0..1] to ZI_DEPARTMENT         as _Department on $projection.DepartmentID = _Department.DepartmentID
  association [0..1] to ZI_LOCATION           as _Location   on $projection.LocationID = _Location.LocationID
  association [0..1] to ZI_REQ_STATUS_VH      as _Status     on $projection.Status = _Status.Status
  association [0..1] to ZI_APPROVER_TEXT      as _Approver   on $projection.ApproverID = _Approver.ApproverID
  association [0..1] to ZI_ASSET_LOAN_REQ_CNT as _Counts     on $projection.RequestUUID = _Counts.RequestUUID
{
  key request_uuid          as RequestUUID,
      request_id            as RequestID,
      requester_id          as RequesterID,
      department_id         as DepartmentID,
      location_id           as LocationID,
      request_date          as RequestDate,
      needed_from_date      as NeededFromDate,
      expected_return_date  as ExpectedReturnDate,
      purpose               as Purpose,
      status                as Status,
      approver_id           as ApproverID,
      rejection_reason      as RejectionReason,
      correction_reason     as CorrectionReason,
      checkout_date         as CheckoutDate,
      completion_date       as CompletionDate,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Items,
      _Department,
      _Location,
      _Status,
      _Approver,
      _Counts
}
