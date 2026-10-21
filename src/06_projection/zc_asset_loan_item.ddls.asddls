@EndUserText.label: 'Asset Loan Item - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ItemNumber']
define view entity ZC_ASSET_LOAN_ITEM
  as projection on ZI_ASSET_LOAN_ITEM
{
  key ItemUUID,
      RequestUUID,
      ItemNumber,
      @ObjectModel.text.element: ['CategoryName']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ASSET_CATEGORY_VH', element: 'CategoryID' } }]
      CategoryID,
      _Category.CategoryName     as CategoryName,
      RequestedQuantity,
      ApprovedQuantity,
      SpecialRequirement,
      @ObjectModel.text.element: ['ItemStatusText']
      ItemStatus,
      _ItemStatus.ItemStatusText as ItemStatusText,
      // used to pre-fill the AssignAsset dialog (dependent asset value help)
      _Request.LocationID        as RequestLocationID,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Request     : redirected to parent ZC_ASSET_LOAN_REQUEST,
      _Assignments : redirected to composition child ZC_ASSET_ASSIGNMENT,
      _Category,
      _ItemStatus
}
