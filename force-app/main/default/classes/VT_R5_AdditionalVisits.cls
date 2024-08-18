/**
 * Created by Bobich Viktar on 28-Jul-20.
 * date:25 August-2022 for testing the pull request functionality
 */

public with sharing class VT_R5_AdditionalVisits {

//commenting for pull request POC
//commenting for github migration 18-08-2024

    public static Map<Id, Map<Id, VTD1_ProtocolVisit__c>> protocolVisitByStudyIdMap;
    public static Map<Id, Map<Id, VTD1_ProtocolVisit__c>> filteredProtocolVisitsByCaseId;
    public static Set<String> caseFieldApiNameSet;
    private static final String RECORD_TYPE_SUBGROUP_TIMELINE_VISIT_NAME = 'Subgroup Timeline Visit';
    private static final String RECORD_TYPE_SUBGROUP_INDICATOR_NAME = 'SubGroup Indicator';
    private static final String OPERATOR_EQUALS = 'equals';
    private static final String OPERATOR_DOES_NOT_EQUALS = 'does not equal';
    private static final String OPERATOR_CONTAINS = 'contains';
    private static final String OPERATOR_IS_NULL = 'is null';
    private static final String OPERATOR_IS_NOT_NULL = 'is not null';
    private static final String FIELD_TYPE_DATE = 'date';
    private static final String DEFAULT_OFFSET_DATE_FIELD = 'VTR5_Day_1_Dose__c';

    /**
    * @description The method take protocol visits for case (considering visit Configurations)
    * @author Viktar Bobich
    * @param patientCaseList (patient case list)
    * @param updatedFieldByCaseIdMap (Updated fields by case Id)
    * @return Map<Id, List<VTD1_ProtocolVisit__c>> Appropriate List protocol visits for case
    * @date 03/08/2020
    * @issue SH-14218, SH-18596
    * @test VT_R5_AdditionalVisitsTest
    */

    public static Map<Id, List<Id>> getAdditionalProtocolVisits(List<Case> patientCaseList, Map<Id, Set<String>> updatedFieldByCaseIdMap){
        Map<Id, List<Id>> protocolVisitIdsByCaseIdMap = new Map<Id, List<Id>>();
        Map<Id, Map<Id, VTD1_ProtocolVisit__c>> protocolVisitByCaseIdMap = getFilteredProtocolVisitsByCase(updatedFieldByCaseIdMap);
        if(protocolVisitByCaseIdMap.isEmpty()){
            return protocolVisitIdsByCaseIdMap;
        }
        for(Case patientCase : patientCaseList){
            Map<Id, Map<Integer, Boolean>> visitConfigAnswerMap = new Map<Id, Map<Integer, Boolean>>();
            Map<Id, VTD1_ProtocolVisit__c> protocolVisitMap = protocolVisitByCaseIdMap.get(patientCase.Id);
            if(protocolVisitMap == null || protocolVisitMap.isEmpty()){
                continue;
            }
            for(VTD1_ProtocolVisit__c protocolVisit : protocolVisitMap.values()){
                Map<Integer, Boolean> booleanByVisitConfigNumber = new Map<Integer, Boolean>();
                for(VTR5_VisitConfiguration__c visitConfiguration : protocolVisit.Visit_Configurations__r){
                    if(checkVisitConfiguration(visitConfiguration, patientCase)){
                        booleanByVisitConfigNumber.put(Integer.valueOf(visitConfiguration.VTR5_ConditionNumber__c) , true);
                    }
                    visitConfigAnswerMap.put(protocolVisit.Id, booleanByVisitConfigNumber);
                }
            }
            List<Id>appropriateProtocolVisitIdForCaseList = new List<Id>();
            for(Id visitId : visitConfigAnswerMap.keySet()){
                if(visitConfigAnswerMap.get(visitId) != null
                        && protocolVisitMap.get(visitId).VTR5_StartLogic__c != null
                        && VT_R5_StringConditionParser.evaluate(protocolVisitMap.get(visitId).VTR5_StartLogic__c, visitConfigAnswerMap.get(visitId))){
                    appropriateProtocolVisitIdForCaseList.add(protocolVisitMap.get(visitId).Id);
                }
            }
            if(!appropriateProtocolVisitIdForCaseList.isEmpty()){
                protocolVisitIdsByCaseIdMap.put(patientCase.Id, appropriateProtocolVisitIdForCaseList);
            }
        }

        return protocolVisitIdsByCaseIdMap;
    }

    /**
    * @description The method return visit configuration fields
    * @author Viktar Bobich
    * @param patientCaseList (patient case list)
    * @return Map<Id, Set<String>> Visit configuration fields for case
    * @date 04/11/2020
    * @issue SH-18596
    * @test VT_R5_AdditionalVisitsTest
    */

    public static Map<Id, Set<String>> getVisitConfigurationField(List<Case> patientCaseList){
        Map<Id, Set<String>> visitConfigurationFieldByCaseId = new Map<Id, Set<String>>();
        protocolVisitByStudyIdMap = getProtocolVisits(RECORD_TYPE_SUBGROUP_TIMELINE_VISIT_NAME, patientCaseList);
        for(Case patientCase : patientCaseList){
            Map<Id, VTD1_ProtocolVisit__c> protocolVisitMap = protocolVisitByStudyIdMap.get(patientCase.VTD1_Study__c);
            Set<String> visitConfigurationFieldList = new Set<String>();

            visitConfigurationFieldByCaseId.put(patientCase.Id, visitConfigurationFieldList);
            if(protocolVisitMap == null || protocolVisitMap.isEmpty()){
                continue;
            }

            for(VTD1_ProtocolVisit__c protocolVisit : protocolVisitMap.values()){
                if (protocolVisit.VTR5_OffsetFrom__r.VTR5_FieldAPIName__c != null) {
                    visitConfigurationFieldList.add(protocolVisit.VTR5_OffsetFrom__r.VTR5_FieldAPIName__c);
                }else{
                    visitConfigurationFieldList.add(DEFAULT_OFFSET_DATE_FIELD);
                }
                for(VTR5_VisitConfiguration__c visitConfiguration : protocolVisit.Visit_Configurations__r) {
                    if (visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c != null) {
                        visitConfigurationFieldList.add(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c);
                    }
                }
                visitConfigurationFieldByCaseId.put(patientCase.Id, visitConfigurationFieldList);
            }
        }
        return visitConfigurationFieldByCaseId;
    }

    public static void createNewVisits(Map<Id, List<Id>> protocolVisitIdsByCaseIdMap){
        VTD1_Queue_Action__c action = new VTD1_Queue_Action__c();
        action.VTD1_Execution_Time__c = Datetime.now().addDays(-1);
        action.VTD1_Action_Class__c = 'VT_R5_QAction_AdditionalVisits';
        action.VTD1_Action_JSON__c = JSON.serialize(new Map<String, Map<Id, List<Id>>>{
                'protocolVisitIdsByCaseIdMap' => protocolVisitIdsByCaseIdMap
        });
        insert action;
    }

    /**
    * @description The method get protocol visits for Case
    * @author Viktar Bobich
    * @param recordTypeName protocol visit record type name
    * @param caseList patient cases
    * @return Map<Id, Map<Id, VTD1_ProtocolVisit__c>>  Map protocol visit by study Id
    * @date 03/08/2020
    * @issue SH-14218
    * @test VT_R5_AdditionalVisitsTest
    */

    public static Map<Id, Map<Id, VTD1_ProtocolVisit__c>> getProtocolVisits (String recordTypeName, List<Case> caseList){
        if(protocolVisitByStudyIdMap != null){
            return protocolVisitByStudyIdMap;
        }
        protocolVisitByStudyIdMap = new Map<Id, Map<Id, VTD1_ProtocolVisit__c>>();
        Set<Id> studyIdSet = new Set<Id>();
        for(Case c : caseList){
            studyIdSet.add(c.VTD1_Study__c);
        }
        List<VTD1_ProtocolVisit__c> protocolVisitList = [
                SELECT  Id,
                        VTD1_EDC_Name__c,
                        VTR5_StartLogic__c,
                        VTD1_Study__c,
                        VTD1_PreVisitInstructions__c,
                        VTD1_Independent_Rater_Flag__c,
                        VTD1_Patient_Visit_Checklist__c,
                        VTD1_Visit_Checklist__c,
                        VTR2_SH_TelevisitNeeded__c,
                        VTR2_Modality__c,
                        VTD1_Study__r.VTD1_Study_Admin__c,
                        VTD1_VisitType__c,
                        VTR5_OffsetFrom__r.VTR5_FieldAPIName__c,
                (SELECT Id,
                        RecordType.Name,
                        VTR5_ConditionNumber__c,
                        VTR5_SubGroupIndicator__c,
                        VTR5_Field__r.Name,
                        VTR5_Field__r.VTR5_FieldAPIName__c,
                        VTR5_Field__r.VTR5_FieldType__c,
                        VTR5_Operator__c,
                        VTR5_Value__c
                FROM Visit_Configurations__r
                WHERE VTR5_ConditionNumber__c != NULL
                AND VTR5_Operator__c != NULL
                AND VTR5_Field__r.VTR5_FieldAPIName__c IN :getObjectFieldSet('Case'))
                FROM VTD1_ProtocolVisit__c
                WHERE VTD1_Study__c IN :studyIdSet
                        AND RecordType.Name = :recordTypeName
                        AND (VTR5_OffsetFrom__r.VTR5_FieldAPIName__c IN :getObjectFieldSet('Case') OR VTR5_OffsetFrom__r.VTR5_FieldAPIName__c = NULL)];
        for(Id studyId : studyIdSet){
            Map<Id, VTD1_ProtocolVisit__c> protocolVisitMap = new Map<Id, VTD1_ProtocolVisit__c>();
            for(VTD1_ProtocolVisit__c protocolVisit : protocolVisitList){
                if(protocolVisit.VTD1_Study__c == studyId && protocolVisit.VTR5_StartLogic__c != null){
                    protocolVisitMap.put(protocolVisit.Id, protocolVisit);
                }
            }
            protocolVisitByStudyIdMap.put(studyId, protocolVisitMap);
        }
        return protocolVisitByStudyIdMap;
    }

    /**
    * @description Check visit configuration and case
    * @author Viktar Bobich
    * @param visitConfiguration (visitConfiguration)
    * @param patientCase (patient case)
    * @return Boolean checkVisitConfiguration
    * @date 04/11/2020
    * @issue SH-18596
    * @test VT_R5_AdditionalVisitsTest
    */

    private static Boolean checkVisitConfiguration (VTR5_VisitConfiguration__c visitConfiguration, Case patientCase){
        Boolean result = false;

        if(visitConfiguration.RecordType.Name == RECORD_TYPE_SUBGROUP_INDICATOR_NAME
                && patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c) != null
                && visitConfiguration.VTR5_Value__c != null){
            if(visitConfiguration.VTR5_Operator__c.equalsIgnoreCase(OPERATOR_EQUALS)
                    && visitConfiguration.VTR5_Field__r.VTR5_FieldType__c.equalsIgnoreCase(FIELD_TYPE_DATE)
                    && Date.valueOf(patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c)) == Date.valueOf(visitConfiguration.VTR5_Value__c)){
                result = true;
            }else if(visitConfiguration.VTR5_Operator__c.equalsIgnoreCase(OPERATOR_EQUALS)
                    && String.valueOf(patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c)).equalsIgnoreCase(visitConfiguration.VTR5_Value__c)){
                result = true;
            }else if(visitConfiguration.VTR5_Operator__c.equalsIgnoreCase(OPERATOR_DOES_NOT_EQUALS)
                    && visitConfiguration.VTR5_Field__r.VTR5_FieldType__c.equalsIgnoreCase(FIELD_TYPE_DATE)
                    && Date.valueOf(patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c)) != Date.valueOf(visitConfiguration.VTR5_Value__c)){
                result = true;
            }else if(visitConfiguration.VTR5_Operator__c.equalsIgnoreCase(OPERATOR_DOES_NOT_EQUALS)
                    && !String.valueOf(patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c)).equalsIgnoreCase(visitConfiguration.VTR5_Value__c)){
                result = true;
            }else if(visitConfiguration.VTR5_Operator__c.equalsIgnoreCase(OPERATOR_CONTAINS)
                    && String.valueOf(patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c)).containsIgnoreCase(visitConfiguration.VTR5_Value__c)){
                result = true;
            }
        }else if(visitConfiguration.RecordType.Name == RECORD_TYPE_SUBGROUP_INDICATOR_NAME){
            if(visitConfiguration.VTR5_Operator__c.equalsIgnoreCase(OPERATOR_IS_NULL)
                    && patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c) == null) {
                result = true;
            }else if(visitConfiguration.VTR5_Operator__c.equalsIgnoreCase(OPERATOR_IS_NOT_NULL)
                    && patientCase.get(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c) != null){
                result = true;
            }
        }
        return result;
    }

    private static Set<String> getObjectFieldSet(String objectName){
        if(caseFieldApiNameSet != null){
            return caseFieldApiNameSet;
        }
        Map <String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
        caseFieldApiNameSet = fieldMap.keySet();
        return caseFieldApiNameSet;
    }

    private static Map<Id, Map<Id, VTD1_ProtocolVisit__c>> getFilteredProtocolVisitsByCase(Map<Id, Set<String>> updatedFieldByCaseIdMap){
        if(filteredProtocolVisitsByCaseId != null){
            return filteredProtocolVisitsByCaseId;
        }
        filteredProtocolVisitsByCaseId = new Map<Id, Map<Id, VTD1_ProtocolVisit__c>>();
        Map<Id, Case> caseByIdMap = (Map<Id, Case>)Trigger.newMap;
        for(Id patientCaseId : updatedFieldByCaseIdMap.keySet()){
            if(protocolVisitByStudyIdMap.containsKey(caseByIdMap.get(patientCaseId).VTD1_Study__c)){
                Map<Id, VTD1_ProtocolVisit__c>filteredProtocolVisitMap = new Map<Id, VTD1_ProtocolVisit__c>();
                for(VTD1_ProtocolVisit__c protocolVisitForStudy : protocolVisitByStudyIdMap.get(caseByIdMap.get(patientCaseId).VTD1_Study__c).values()){
                    for(VTR5_VisitConfiguration__c visitConfiguration : protocolVisitForStudy.Visit_Configurations__r) {
                        if(updatedFieldByCaseIdMap.get(patientCaseId).contains(visitConfiguration.VTR5_Field__r.VTR5_FieldAPIName__c)) {
                            filteredProtocolVisitMap.put(protocolVisitForStudy.Id, protocolVisitForStudy);
                        }
                    }
                }
                if(!filteredProtocolVisitMap.isEmpty()){
                    filteredProtocolVisitsByCaseId.put(patientCaseId, filteredProtocolVisitMap);
                }
            }
        }

        return filteredProtocolVisitsByCaseId;
    }
  private static void showMessage()
  {
        system.debug('hello::checking');
  }
  //adding one line for testing
  //adding second line for testing
  //adding third line for testing
  //adding comment to test a functionality 
  //Adding components to for functioality test 
  //Adding components to for functioality recommiting purpose 
}