@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approver Name per User'
define view entity ZI_APPROVER_TEXT
  as select from zrap_asset_appr
{
  key approver_id          as ApproverID,
      max( approver_name ) as ApproverName
}
group by
  approver_id
