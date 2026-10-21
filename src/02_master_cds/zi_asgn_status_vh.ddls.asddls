@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Assignment Status Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ASGN_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZRAP_D_ASGN_STATUS' )
{
      @ObjectModel.text.element: ['AssignmentStatusText']
  key cast( value_low as abap.char( 2 ) ) as AssignmentStatus,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )     as AssignmentStatusText,
      cast( case value_low
              when '01' then 5
              when '02' then 2
              when '03' then 3
              when '04' then 1
              else 0
            end as abap.int1 )            as Criticality
}
where
  language = $session.system_language
