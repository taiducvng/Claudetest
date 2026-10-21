@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Department'
define view entity ZI_DEPARTMENT
  as select from zrap_department
{
  key department_id   as DepartmentID,
      @Semantics.text: true
      department_name as DepartmentName,
      manager_id      as ManagerID,
      is_active       as IsActive
}
