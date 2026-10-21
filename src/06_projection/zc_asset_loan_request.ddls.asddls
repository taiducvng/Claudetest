@EndUserText.label: 'Asset Loan Request - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['RequestID']
define root view entity ZC_ASSET_LOAN_REQUEST
  provider contract transactional_query
  as projection on ZI_ASSET_LOAN_REQUEST
{
  key RequestUUID,
      @Search.defaultSearchElement: true
      RequestID,
      @Search.defaultSearchElement: true
      RequesterID,
      @ObjectModel.text.element: ['DepartmentName']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_DEPARTMENT_VH', element: 'DepartmentID' } }]
      DepartmentID,
      _Department.DepartmentName as DepartmentName,
      @ObjectModel.text.element: ['LocationName']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_LOCATION_VH', element: 'LocationID' } }]
      LocationID,
      _Location.LocationName     as LocationName,
      RequestDate,
      NeededFromDate,
      ExpectedReturnDate,
      Purpose,
      @ObjectModel.text.element: ['StatusText']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_REQ_STATUS_VH', element: 'Status' } }]
      Status,
      _Status.StatusText         as StatusText,
      _Status.Criticality        as StatusCriticality,
      @ObjectModel.text.element: ['ApproverName']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ASSET_APPROVER_VH', element: 'ApproverID' } }]
      ApproverID,
      _Approver.ApproverName     as ApproverName,
      RejectionReason,
      CorrectionReason,
      CheckoutDate,
      CompletionDate,
      _Counts.RequestedItemCount as RequestedItemCount,
      _Counts.AssignedAssetCount as AssignedAssetCount,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Items : redirected to composition child ZC_ASSET_LOAN_ITEM,
      _Department,
      _Location,
      _Status,
      _Approver,
      _Counts
}
