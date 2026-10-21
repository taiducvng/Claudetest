@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Return Condition Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_RETURN_CONDITION_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZRAP_D_CONDITION' )
{
      @ObjectModel.text.element: ['ConditionText']
  key cast( value_low as abap.char( 2 ) ) as ConditionCode,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )     as ConditionText
}
where
  language = $session.system_language
