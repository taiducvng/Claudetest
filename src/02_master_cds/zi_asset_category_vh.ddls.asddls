@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Asset Category Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_ASSET_CATEGORY_VH
  as select from ZI_ASSET_CATEGORY
{
      @ObjectModel.text.element: ['CategoryName']
      @Search.defaultSearchElement: true
  key CategoryID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      CategoryName,
      MaxLoanDays
}
where
  IsActive = 'X'
