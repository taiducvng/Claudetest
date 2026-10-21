@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Department Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true
define view entity ZI_DEPARTMENT_VH
  as select from ZI_DEPARTMENT
{
      @ObjectModel.text.element: ['DepartmentName']
      @Search.defaultSearchElement: true
  key DepartmentID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      DepartmentName,
      ManagerID
}
where
  IsActive = 'X'
