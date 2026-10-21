@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approver Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_ASSET_APPROVER_VH
  as select from zrap_asset_appr
{
      @Search.defaultSearchElement: true
  key approver_id   as ApproverID,
  key department_id as DepartmentID,
  key category_id   as CategoryID,
      @Search.defaultSearchElement: true
      approver_name as ApproverName
}
where
  is_active = 'X'
