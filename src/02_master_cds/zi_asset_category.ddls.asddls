@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Asset Category'
define view entity ZI_ASSET_CATEGORY
  as select from zrap_asset_cat
{
  key category_id       as CategoryID,
      @Semantics.text: true
      category_name     as CategoryName,
      max_loan_days     as MaxLoanDays,
      approval_required as ApprovalRequired,
      priority          as Priority,
      is_active         as IsActive
}
