@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Asset Loan Request - Counters'
// Read-only helper for List Report columns "Requested Items" / "Assigned Assets"
define view entity ZI_ASSET_LOAN_REQ_CNT
  as select from    zrap_asset_req_h as h
    left outer join zrap_asset_req_i as i on i.request_uuid = h.request_uuid
    left outer join zrap_asset_asgn  as a on  a.request_uuid      = h.request_uuid
                                          and a.assignment_status <> '05'
{
  key h.request_uuid                      as RequestUUID,
      count( distinct i.item_uuid )       as RequestedItemCount,
      count( distinct a.assignment_uuid ) as AssignedAssetCount
}
group by
  h.request_uuid
