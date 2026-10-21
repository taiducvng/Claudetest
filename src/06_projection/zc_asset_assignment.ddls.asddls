@EndUserText.label: 'Assigned Asset - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity ZC_ASSET_ASSIGNMENT
  as projection on ZI_ASSET_ASSIGNMENT
{
  key AssignmentUUID,
      RequestUUID,
      ItemUUID,
      AssetUUID,
      _Asset.AssetID                         as AssetID,
      _Asset.AssetName                       as AssetName,
      _Asset.SerialNumber                    as SerialNumber,
      AssignedBy,
      AssignedAt,
      CheckoutDate,
      ReturnDate,
      @ObjectModel.text.element: ['ReturnConditionText']
      ReturnCondition,
      _ReturnCondition.ConditionText         as ReturnConditionText,
      ReturnNote,
      @ObjectModel.text.element: ['AssignmentStatusText']
      AssignmentStatus,
      _AssignmentStatus.AssignmentStatusText as AssignmentStatusText,
      _AssignmentStatus.Criticality          as AssignmentStatusCriticality,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Item    : redirected to parent ZC_ASSET_LOAN_ITEM,
      _Request : redirected to ZC_ASSET_LOAN_REQUEST,
      _Asset,
      _AssignmentStatus,
      _ReturnCondition
}
