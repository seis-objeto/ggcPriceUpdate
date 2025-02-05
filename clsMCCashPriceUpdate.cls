VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsMCCashPriceUpdate"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
'
' Guanzon Software Engineering Group
' Guanzon Group of Companies
' Perez Blvd., Dagupan City
'
'     Update MC Price History
'
' Copyright 2007 and Beyond
' All Rights Reserved
' ºººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººº
'   All  rights reserved. No part of this  software    This Software is Owned by        
'   may be reproduced or transmitted in any form or                                     
'   by   any   means,  electronic   or  mechanical,      GUANZON MERCHANDISING CORP.    
'   including recording, or by information  storage       Guanzon Bldg. Perez Blvd.     
'   and  retrieval  systems, without  prior written             Dagupan City            
'   from the author.                                   Tel No. 522-1085 ; 522-9275      
' ºººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººººº
'
' ==========================================================================================
'  XerSys [ 03/30/2009 10:58 am ]
'     Start coding this object...
'  XerSys [ 09/04/2013 11:45 am ]
'     Insert user authentication in saving pricelist
'
Option Explicit

Private Const pxeMODULENAME As String = "clsMCCashPriceUpdate"
Private Const pxeChangeFrom As String = "0"
Private Const pxeAllowable As Integer = 224

Private p_oAppDrivr As clsAppDriver
Private p_oDetail As Recordset
Private p_oHistry As Recordset

Private p_sSQLMastr As String

Private p_sMCCatIDx As String
Private p_sMCCatNme As String
Private p_nMarkUpRt As Double
Private p_nMarkUpAm As Double
Private p_dPricexxx As Date
Private p_sApproved As String

Private p_sBranchCd As String
Private p_sParentxx As String

Private p_cTranStat As xeTransactionStatus

Private pbInitTran As Boolean
Private pbDetModified As Boolean

Private pbShowMsg As Boolean

Public Event DetailRetrieved()
Public Event MasterRetrieved(ByVal Index As Integer)

Property Set AppDriver(oAppDriver As clsAppDriver)
   Set p_oAppDrivr = oAppDriver
End Property

Property Get Branch() As String
   Branch = p_sBranchCd
End Property

Property Let Branch(ByVal Value As String)
   p_sBranchCd = Value
End Property

Property Get Detail(ByVal Row As Long, Index As Variant) As Variant
   On Error Resume Next
   
   If pbInitTran = False Then Exit Property
   
   If Row > (p_oDetail.RecordCount - 1) Then Exit Property
   p_oDetail.Move Row, adBookmarkFirst
   
   Detail = p_oDetail(Index)
End Property

Property Let Detail(ByVal Row As Long, Index As Variant, Value As Variant)
   On Error Resume Next
   
   If pbInitTran = False Then Exit Property
   With p_oDetail
      If Row > .RecordCount Then
         Exit Property
      ElseIf Row = .RecordCount Then
         ' check first if last record have a valid parts id
         If .Fields("sModelIDx") = Empty Then
            MsgBox "Inserting Empty Record is Not Allowed!" & vbCrLf & vbCrLf & _
                  "Please inform the SEG/SSG of Guanzon Group of Companies!", vbCritical, "Warning"
            Exit Property
         End If
         
         Call AddDetail
      Else
         .Move Row, adBookmarkFirst
      End If
   
      If Not IsNumeric(Index) Then Index = LCase(Index)
      Select Case Index
      Case 1, "smodelnme"
         If pbDetModified = False Then
            pbDetModified = p_oDetail(Index) = Value
         End If
         
         Call getDetail(Value, False)
      Case 2, "smodelcde"
      Case 3, "nbrandnme"
         p_oDetail(Index) = Value
      Case 4, 5, 6, "nselprice", "nlastprce", "ndealrprc"
         If Not IsNumeric(Value) Then Exit Property
         
         If pbDetModified = False Then
            pbDetModified = p_oDetail(Index) = CDbl(Value)
         End If
         
         p_oDetail(Index) = CDbl(Value)
         Debug.Print Index, Value, p_oDetail(Index)
      End Select
   End With
End Property

Property Let DisplayConfirmation(Value As Boolean)
   pbShowMsg = Value
End Property

Property Get Master(Index As Variant) As Variant
   If pbInitTran = False Then Exit Property
   
   If Not IsNumeric(Index) Then Index = LCase(Index)
   Select Case Index
   Case 0, "smccatidx"
      Master = p_sMCCatIDx
   Case 1, "smccatnme"
      Master = p_sMCCatNme
   Case 2, "dpricexxx"
      Master = p_dPricexxx
   Case 3, "nmarkuprt"
      Master = p_nMarkUpRt
   Case 4, "nmarkupam"
      Master = p_nMarkUpAm
   End Select
End Property

Property Let Master(Index As Variant, Value As Variant)
   If pbInitTran = False Then Exit Property
   
   If Not IsNumeric(Index) Then Index = LCase(Index)
   Select Case Index
   Case 0, "smccatidx"
   Case 1, "smccatnme"
      Call getMaster(Value, False)
   Case 2, "dpricexxx"
      If Not IsDate(Value) Then Exit Property
   
      p_dPricexxx = Value
   Case 3, "nmarkuprt"
      If Not IsNumeric(Value) Then Exit Property
      
      p_nMarkUpRt = Value
   Case 4, "nmarkupam"
      If Not IsNumeric(Value) Then Exit Property
      
      p_nMarkUpAm = Value
   End Select
End Property

Property Let Parent(ByVal Value As String)
   p_sParentxx = Value
End Property

Property Get ItemCount() As Long
   If pbInitTran = False Then Exit Property
   
   ItemCount = p_oDetail.RecordCount
End Property

Function InitTransaction() As Boolean
   Dim lsProcName As String
   Dim lsSQLBrows As String
   
   lsProcName = "InitTransaction"
   On Error GoTo errProc
   InitTransaction = False

   If isAppDriverOK(p_oAppDrivr) = False Then
      MsgBox "Application Driver is Not Initialized for this Object!" & vbCrLf & _
            "Set Application Driver First then Try Again!", vbCritical, "Warning"
      GoTo endProc
   End If
   
   If p_sBranchCd = Empty Then p_sBranchCd = p_oAppDrivr.BranchCode
   
   p_sSQLMastr = "SELECT" & _
                     "  a.sModelIDx" & _
                     ", b.sModelNme" & _
                     ", b.sModelCde" & _
                     ", d.sBrandNme" & _
                     ", a.nSelPrice" & _
                     ", a.nLastPrce" & _
                     ", a.nDealrPrc" & _
                     ", c.sMCCatNme" & _
                     ", a.sApproved" & _
                     ", a.dPricexxx" & _
                     ", a.nMinDownx" & _
                     ", a.sModified" & _
                     ", a.dModified" & _
                     ", a.sMCCatIDx" & _
                     ", a.cRecdStat" & _
                  " FROM MC_Model_Price a" & _
                     ", MC_Model b" & _
                     ", MC_Category c" & _
                     ", Brand d" & _
                  " WHERE a.sModelIDx = b.sModelIDx" & _
                     " AND a.sMCCatIDx = c.sMCCatIDx" & _
                     " AND b.sBrandIDx = d.sBrandIDx AND a.cRecdStat = " & strParm(xeRecStateActive) & _
                     " AND b.cRecdStat = " & strParm(xeRecStateActive) & _
                  " ORDER BY b.sModelNme"
                  
   p_sMCCatIDx = ""
   p_sMCCatNme = ""
   p_nMarkUpRt = 0#
   p_nMarkUpAm = 0#
   p_dPricexxx = Date
   p_sApproved = ""
   
   Set p_oDetail = New Recordset
   p_oDetail.Open AddCondition(p_sSQLMastr, "0 = 1"), p_oAppDrivr.Connection, adOpenStatic, adLockOptimistic, adCmdText
   Set p_oDetail.ActiveConnection = Nothing
   If p_oDetail.EOF Then p_oDetail.AddNew
   
   pbInitTran = True
   
endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Function SaveTransaction() As Boolean
   Dim lsProcName As String
   Dim lsSQL As String
   Dim lsApproved As String, lsApprvNme As String
   Dim lnRights As Integer

   
   lsProcName = "p_oBaseClas_WillSave"
   On Error GoTo errProc
   
   If MsgBox("Are you sure you want to Save this Transaction?", _
         vbYesNo + vbInformation, "Confirm") <> vbYes Then GoTo endProc
   
   ' XerSys - 2013-09-04
   '  Check user level
   If p_oAppDrivr.UserLevel < xeUserRights.xeSysOwner Then
      If Not GetApproval(p_oAppDrivr, lnRights, lsApproved, lsApprvNme, pxeAllowable) Then
         MsgBox "User is not authorized to Update Motorcycle Price!" & vbCrLf & _
               "Verify your entry then try again!", vbOKOnly + vbCritical, "Warning"
         GoTo endProc
      End If
   End If
   
   lsSQL = AddCondition(p_sSQLMastr, "a.sMCCatIDx = " & strParm(p_sMCCatIDx))
   Set p_oHistry = New Recordset
   p_oHistry.Open lsSQL, p_oAppDrivr.Connection, , , adCmdText
   
   p_oHistry.Sort = "sModelIDx"
   p_oDetail.Sort = "sModelIDx"
   
   p_oAppDrivr.BeginTrans
reCompare:
   Do While p_oDetail.EOF = False
      If p_oHistry.EOF = False Then
         Select Case StrComp(p_oDetail("sModelIDx"), p_oHistry("sModelIDx"), vbTextCompare)
         Case -1 ' Modified < Original
            If addNewModel() = False Then
               p_oAppDrivr.RollbackTrans
               GoTo endProc
            End If
         Case 0 ' Equal
            If p_oDetail("nSelPrice") <> p_oHistry("nSelPrice") Or _
                  p_oDetail("nLastPrce") <> p_oHistry("nLastPrce") Or _
                  p_oDetail("nDealrPrc") <> p_oHistry("nDealrPrc") Then
               If updateModelPrice() = False Then
                  p_oAppDrivr.RollbackTrans
                  GoTo endProc
               End If
            End If
            p_oHistry.MoveNext
         Case 1  ' Modified > original
            With p_oHistry
               Do
                  If StrComp(p_oDetail.Fields("sModelIDx"), _
                        p_oHistry("sModelIDx"), vbTextCompare) = 1 Then
                     Debug.Print "Remove " & p_oHistry("sModelIDx")
                     If removeModel() = False Then
                        p_oAppDrivr.RollbackTrans
                        GoTo endProc
                     End If
                  Else
                     Exit Do
                  End If
                  
                  .MoveNext
               Loop Until .EOF
            End With
            GoTo reCompare
         End Select
      Else
         If addNewModel() = False Then
            p_oAppDrivr.RollbackTrans
            GoTo endProc
         End If
      End If
      
      p_oDetail.MoveNext
   Loop
   
   Do Until p_oHistry.EOF
      If removeModel() = False Then
         p_oAppDrivr.RollbackTrans
         GoTo endProc
      End If
      p_oHistry.MoveNext
   Loop
   
   p_oAppDrivr.CommitTrans
   
   pbDetModified = False
   SaveTransaction = True
   
endProc:
   Set p_oHistry = Nothing
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Function SearchDetail(ByVal Row As Long, _
                        ByVal Index As Variant, _
                        Optional Value As Variant = "") As Boolean
   Dim lsProcName As String

   lsProcName = "SearchDetail"
   On Error GoTo errProc
   SearchDetail = False

   Debug.Print p_oDetail.RecordCount
   If pbInitTran = False Then GoTo endProc

   If Row > (p_oDetail.RecordCount - 1) Then GoTo endProc
   If p_oDetail.AbsolutePosition <> Row + 1 Then
      p_oDetail.Move Row, adBookmarkFirst
   End If
   
   Index = LCase(Index)
   Select Case Index
   Case 1, "smodelnme"
      getDetail Value, True
   End Select
   
   SearchDetail = True

endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Function SearchMaster(ByVal Index As Variant, Optional Value As Variant = "") As Boolean
   If pbInitTran = False Then Exit Function
   
   If Not IsNumeric(Index) Then Index = LCase(Index)
   Select Case Index
   Case 1, "smccatnme"
      getMaster Value, True
   End Select
   
   SearchMaster = True
End Function

Function DeleteDetail(ByVal Row As Long) As Boolean
   Dim lsProcName As String
   
   lsProcName = "DeleteDetail"
   On Error GoTo errProc
   
   If pbInitTran = False Then GoTo endProc
   
   If Row > (p_oDetail.RecordCount - 1) Then GoTo endProc
   
   p_oDetail.Move Row, adBookmarkFirst
   p_oDetail.Delete adAffectCurrent
   
   DeleteDetail = True
   
endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Sub AddDetail()
   Dim lsProcName As String
   
   lsProcName = "addDetail"
   On Error GoTo errProc

   If p_oDetail("sModelIDx") = "" Then
      MsgBox "Inserting Empty Record is Not Allowed!" & vbCrLf & vbCrLf & _
            "Please inform the SEG/SSG of Guanzon Group of Companies!", vbCritical, "Warning"
   End If
   
   p_oDetail.AddNew
   
endProc:
   Exit Sub
errProc:
   ShowError lsProcName & "( " & " )"
End Sub

Function MarkUpPrice() As Boolean
   Dim lsProcName As String
   
   lsProcName = "MarkUpPrice"
   On Error GoTo errProc
   
   p_oDetail.MoveFirst
   Do While p_oDetail.EOF = False
      p_oDetail("nSelPrice") = Round(p_oDetail("nSelPrice") * (1 + (p_nMarkUpRt / 100)), 0) + p_nMarkUpAm
      p_oDetail("nLastPrce") = Round(p_oDetail("nLastPrce") * (1 + (p_nMarkUpRt / 100)), 0) + p_nMarkUpAm
      p_oDetail("nDealrPrc") = Round(p_oDetail("nDealrPrc") * (1 + (p_nMarkUpRt / 100)), 0) + p_nMarkUpAm
      
      p_oDetail.MoveNext
   Loop
   
   MarkUpPrice = True
   
endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Function UnMarkUpPrice() As Boolean
   Dim lsProcName As String
   
   lsProcName = "UnMarkUpPrice"
   On Error GoTo errProc
   
   p_oDetail.MoveFirst
   Do While p_oDetail.EOF = False
      p_oDetail("nSelPrice") = Round((p_oDetail("nSelPrice") - p_nMarkUpAm) / (1 + (p_nMarkUpRt / 100)), 0)
      p_oDetail("nLastPrce") = Round((p_oDetail("nLastPrce") - p_nMarkUpAm) / (1 + (p_nMarkUpRt / 100)), 0)
      p_oDetail("nDealrPrc") = Round((p_oDetail("nDealrPrc") - p_nMarkUpAm) / (1 + (p_nMarkUpRt / 100)), 0)
      
      p_oDetail.MoveNext
   Loop
   
   UnMarkUpPrice = True
   
endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Private Sub getMaster(ByVal lsValue As String, ByVal lbSearch As Boolean)
   Dim loRS As Recordset
   Dim lsProcName As String
   Dim lsSelect As String
   Dim lasSelect() As String
   Dim lsSQL As String

   lsProcName = "getMaster"
   On Error GoTo errProc
   
   If lsValue <> "" Then
      If lsValue = p_sMCCatNme Then GoTo endProc
      If lbSearch Then
         lsSQL = "sMCCatNme LIKE " & strParm(Trim(lsValue) & "%")
      Else
         lsSQL = "sMCCatNme = " & strParm(Trim(lsValue))
      End If
   ElseIf lbSearch = False Then
      GoTo endWithClear
   End If
   
   lsSQL = "SELECT" & _
               "  sMCCatIDx" & _
               ", sMCCatNme" & _
            " FROM MC_Category" & _
            IIf(lsSQL <> Empty, " WHERE " & lsSQL, "")
            
   Set loRS = New Recordset
   loRS.Open lsSQL, p_oAppDrivr.Connection, , , adCmdText
   
   If loRS.EOF Then
      GoTo endWithClear
   ElseIf loRS.RecordCount > 1 Then
      lsSelect = KwikBrowse(p_oAppDrivr, loRS _
                           , "sMCCatIDx»sMCCatNme" _
                           , "Code»Category Name")

      If lsSelect <> "" Then
         lasSelect = Split(lsSelect, "»")
         
         loRS.MoveFirst
         loRS.Find "sMCCatIDx = " & strParm(lasSelect(0)), 0, adSearchForward
         Debug.Print loRS.EOF
      End If
   End If
   
   If pbDetModified Then
      If p_sMCCatIDx <> loRS("sMCCatIDx") Then
         If MsgBox("Some of the Prices were modified!" & vbCrLf & _
                  "Loading New Set of MC Model will DISCARD modified Price/s!" & vbCrLf & vbCrLf & _
                  "CONTINUE ANYWAY?", vbQuestion + vbYesNo, "Confirm") <> vbYes Then
            GoTo endProc
         End If
      End If
   End If
   
   p_sMCCatIDx = loRS("sMCCatIDx")
   p_sMCCatNme = loRS("sMCCatNme")
   
   Call loadDetail
   
endProc:
   RaiseEvent MasterRetrieved(1)
   Exit Sub
endWithClear:
   p_sMCCatIDx = ""
   p_sMCCatNme = ""
   GoTo endProc
errProc:
   ShowError lsProcName & "( " & lsValue _
                        & ", " & lbSearch & " )"
End Sub

Private Sub getDetail(ByVal lsValue As String, _
                        ByVal lbSearch As Boolean)
   Dim loRS As Recordset
   Dim lsProcName As String
   Dim lsSelect As String
   Dim lasSelect() As String
   Dim lsSQL As String

   lsProcName = "getDetail"
   On Error GoTo errProc
   
   If lsValue <> "" Then
      If lsValue = p_oDetail("sModelNme") Then GoTo endProc
      If lbSearch Then
         lsSelect = "a.sModelNme LIKE " & strParm(Trim(lsValue) & "%")
      Else
         lsSelect = "a.sModelNme = " & strParm(Trim(lsValue))
      End If
   ElseIf lbSearch = False Then
      GoTo endWithClear
   End If
   
   lsSQL = "SELECT" & _
               "  a.sModelIDx" & _
               ", a.sModelNme" & _
               ", a.sModelCde" & _
               ", c.sBrandNme" & _
               ", b.nSelPrice" & _
               ", b.nLastPrce" & _
               ", b.nDealrPrc" & _
               ", b.dPricexxx" & _
               ", b.nMinDownx" & _
               ", b.sModified" & _
               ", b.dModified" & _
               ", b.sMCCatIDx" & _
               ", b.cRecdStat" & _
            " FROM MC_Model a" & _
               " LEFT JOIN MC_Model_Price b" & _
                  " ON a.sModelIDx = b.sModelIDx" & _
               ", Brand c" & _
            " WHERE a.sBrandIDx = c.sBrandIDx" & _
               " AND (b.sMCCatIDx IS NULL" & _
                  " OR b.sMCCatIDx <> " & strParm(p_sMCCatIDx) & _
                  " OR ( b.sMCCatIDx = " & strParm(p_sMCCatIDx) & _
                     " AND b.cRecdStat = " & strParm(xeRecStateInactive) & " ) )" & _
            " ORDER BY a.sModelNme"
            
   If lsSelect <> "" Then
      lsSQL = AddCondition(lsSQL, lsSelect)
   End If
   
   Set loRS = New Recordset
   loRS.Open lsSQL, p_oAppDrivr.Connection, , , adCmdText
   
   If loRS.EOF Then
      GoTo endWithClear
   ElseIf loRS.RecordCount > 1 Then
      lsSelect = KwikBrowse(p_oAppDrivr, loRS _
                           , "sModelIDx»sModelNme»sModelCde»sBrandNme" _
                           , "Code»Model Name»Model Code»Brand")

      If lsSelect = "" Then
         If lbSearch Then
            GoTo endProc
         Else
            GoTo endWithClear
         End If
      Else
         lasSelect = Split(lsSelect, "»")
         
         loRS.MoveFirst
         loRS.Find "sModelIDx = " & strParm(lasSelect(0)), 0, adSearchForward
      End If
   End If
   
   p_oDetail("sModelIDx") = loRS("sModelIDx")
   p_oDetail("sModelCde") = loRS("sModelCde")
   p_oDetail("sModelNme") = loRS("sModelNme")
   p_oDetail("sBrandNme") = loRS("sBrandNme")
   If IsNull(loRS("nSelPrice")) Then
      p_oDetail("nSelPrice") = 0#
      p_oDetail("nLastPrce") = 0#
      p_oDetail("nDealrPrc") = 0#
      p_oDetail("dPricexxx") = p_dPricexxx
      p_oDetail("nMinDownx") = 0#
      p_oDetail("sMCCatIDx") = ""
      p_oDetail("cRecdStat") = xeRecStateActive
   Else
      p_oDetail("nSelPrice") = loRS("nSelPrice")
      p_oDetail("nLastPrce") = loRS("nLastPrce")
      p_oDetail("nDealrPrc") = loRS("nDealrPrc")
      p_oDetail("dPricexxx") = loRS("dPricexxx")
      p_oDetail("nMinDownx") = loRS("nMinDownx")
      p_oDetail("sModified") = loRS("sModified")
      p_oDetail("dModified") = loRS("dModified")
      p_oDetail("sMCCatIDx") = loRS("sMCCatIDx")
      p_oDetail("cRecdStat") = xeRecStateUnknown
   End If
   
endProc:
   RaiseEvent DetailRetrieved
   Exit Sub
endWithClear:
   p_oDetail("sModelIDx") = ""
   p_oDetail("sModelNme") = ""
   p_oDetail("sModelCde") = ""
   p_oDetail("nSelPrice") = 0#
   p_oDetail("nLastPrce") = 0#
   p_oDetail("nDealrPrc") = 0#
   p_oDetail("dPricexxx") = p_dPricexxx
   p_oDetail("nMinDownx") = 0#
   p_oDetail("sMCCatIDx") = ""
   p_oDetail("cRecdStat") = xeRecStateInactive
   GoTo endProc
errProc:
   ShowError lsProcName & "( " & lsValue _
                        & ", " & lbSearch & " )"
End Sub

Private Sub loadDetail()
   Dim lsProcName As String

   lsProcName = "loadDetail"
   On Error GoTo errProc
   
   Set p_oDetail = New Recordset
   p_oDetail.Open AddCondition(p_sSQLMastr, "a.sMCCatIDx = " & strParm(p_sMCCatIDx)), _
            p_oAppDrivr.Connection, adOpenStatic, adLockOptimistic, adCmdText
   
   ' if no record exist, add empty rec
   Set p_oDetail.ActiveConnection = Nothing
   If p_oDetail.EOF Then p_oDetail.AddNew
   
   pbDetModified = False
   
endProc:
   Exit Sub
errProc:
   ShowError lsProcName & "( " & " )"
End Sub

Private Function addNewModel() As Boolean
   Dim lsProcName As String
   Dim lsSQL As String

   lsProcName = "addNewModel"
   On Error GoTo errProc
   
   'From other model
'   If Not (p_oDetail("sModelIDx") = "M00105001" Or p_oDetail("sModelIDx") = "M0W105032") Then
   If p_oDetail("cRecdStat") = xeRecStateUnknown Then
'      If createNotice(p_oDetail("sModelIDx"), IFNull(p_oDetail("sMCCatIDx"), ""), p_sMCCatIDx) Then
         addNewModel = updateMCCategory
'      End If
      GoTo endProc
   Else
      ' create a record that will inform installment price update
      '  of a new model
      If createNotice(p_oDetail("sModelIDx"), "", p_sMCCatIDx) = False Then GoTo endProc
   End If
'   End If
   lsSQL = "INSERT INTO MC_Model_Price SET" & _
               "  sModelIDx = " & strParm(p_oDetail("sModelIDx")) & _
               ", nSelPrice = " & p_oDetail("nSelPrice") & _
               ", nLastPrce = " & p_oDetail("nLastPrce") & _
               ", nDealrPrc = " & p_oDetail("nDealrPrc") & _
               ", sMCCatIDx = " & strParm(p_sMCCatIDx) & _
               ", nMinDownx = " & 0 & _
               ", sApproved = " & strParm(p_oAppDrivr.UserID) & _
               ", dPricexxx = " & dateParm(p_dPricexxx) & _
               ", cRecdStat = " & strParm(xeRecStateActive) & _
               ", sPrepared = " & strParm(p_oAppDrivr.UserID) & _
               ", dPrepared = " & dateParm(p_oAppDrivr.SysDate)
   
   If p_oAppDrivr.Execute(lsSQL, "MC_Model_Price") <= 0 Then
      MsgBox "Unable to Insert New Record!", vbCritical, "Warning"
      GoTo endProc
   End If
   
   addNewModel = True
   
endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Private Function updateModelPrice() As Boolean
   Dim lsProcName As String
   Dim lsSQL As String

   lsProcName = "updateModelPrice"
   On Error GoTo errProc
   Debug.Print lsProcName
   
   ' first move the existing record to history table
   lsSQL = "INSERT INTO MC_Model_Price_History " & _
               "( sModelIDx" & _
               ", dPricexxx" & _
               ", nPurPrice" & _
               ", nSelPrice" & _
               ", nLastPrce" & _
               ", nDealrPrc" & _
               ", nMinDownx" & _
               ", sMCCatIDx" & _
               ", sModified" & _
               ", dModified )" & _
               " ( SELECT" & _
                  "  sModelIDx" & _
                  ", dPricexxx" & _
                  ", nPurPrice" & _
                  ", nSelPrice" & _
                  ", nLastPrce" & _
                  ", nDealrPrc" & _
                  ", nMinDownx" & _
                  ", sMCCatIDx" & _
                  ", sModified" & _
                  ", dModified" & _
               " FROM MC_Model_Price" & _
               " WHERE sModelIDx = " & strParm(p_oHistry("sModelIDx")) & _
                  " AND dPricexxx = " & dateParm(p_oHistry("dPricexxx")) & " )"

   If p_oAppDrivr.Execute(lsSQL, "MC_Model_Price_History") <= 0 Then
      MsgBox "Unable to Insert Record to History!", vbCritical, "Warning"
      GoTo endProc
   End If
            
   ' now update the current pricelist
   lsSQL = "UPDATE MC_Model_Price SET" & _
               "  sModelIDx = " & strParm(p_oDetail("sModelIDx")) & _
               ", dPricexxx = " & dateParm(p_dPricexxx) & _
               ", nSelPrice = " & p_oDetail("nSelPrice") & _
               ", nLastPrce = " & p_oDetail("nLastPrce") & _
               ", nDealrPrc = " & p_oDetail("nDealrPrc") & _
               ", sModified = " & strParm(p_oAppDrivr.UserID) & _
               ", dModified = " & dateParm(p_oAppDrivr.SysDate) & _
            " WHERE sModelIDx = " & strParm(p_oDetail("sModelIDx"))
            
   If p_oAppDrivr.Execute(lsSQL, "MC_Model_Price") <= 0 Then
      MsgBox "Unable to Update Price to Info!", vbCritical, "Warning"
      GoTo endProc
   End If

   updateModelPrice = True

endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Private Function removeModel() As Boolean
   Dim lsProcName As String
   Dim lsSQL As String

   lsProcName = "removeModel"
   On Error GoTo errProc
   
   ' now update the current pricelist
   lsSQL = "UPDATE MC_Model_Price SET" & _
               "  cRecdStat = " & strParm(xeRecStateInactive) & _
               ", sMCCatIDx = " & strParm("") & _
               ", sModified = " & strParm(p_oAppDrivr.UserID) & _
               ", dModified = " & dateParm(p_oAppDrivr.SysDate) & _
            " WHERE sModelIDx = " & strParm(p_oHistry("sModelIDx"))
            
   If p_oAppDrivr.Execute(lsSQL, "MC_Model_Price") <= 0 Then
      MsgBox "Unable to Delete Price Info!", vbCritical, "Warning"
      GoTo endProc
   End If

   removeModel = createNotice(p_oHistry("sModelIDx"), p_oHistry("sMCCatIDx"), "")

endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Private Function createNotice(lsModelIDx As String, lsPrvCatIDx As String, lsMCCatIDx As String) As Boolean
   Dim lsProcName As String
   Dim lsSQL As String

   lsProcName = "createNotice"
   On Error GoTo errProc
   
   ' now update the current pricelist
   lsSQL = "INSERT INTO MC_Category_Changes SET" & _
               "  sModelIDx = " & strParm(lsModelIDx) & _
               ", sPrvCatID = " & strParm(lsPrvCatIDx) & _
               ", sPrsCatID = " & strParm(lsMCCatIDx) & _
               ", dTransact = " & dateParm(p_dPricexxx) & _
               ", cChangeFr = " & strParm(pxeChangeFrom) & _
               ", sModified = " & strParm(p_oAppDrivr.UserID) & _
               ", dModified = " & dateParm(p_oAppDrivr.SysDate)

   Debug.Print lsSQL
   If p_oAppDrivr.Execute(lsSQL, "MC_Model_Price") <= 0 Then GoTo endProc

   createNotice = True

endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Private Function updateMCCategory() As Boolean
   Dim lsProcName As String
   Dim lsSQL As String

   lsProcName = "updateMCCatogery"
   On Error GoTo errProc
   Debug.Print lsProcName
   
   ' first move the existing record to history table
   If Not IsNull(p_oDetail("dPricexxx")) Then
      ' Only existing entry must have history
      lsSQL = "INSERT INTO MC_Model_Price_History " & _
                  "( sModelIDx" & _
                  ", dPricexxx" & _
                  ", nPurPrice" & _
                  ", nSelPrice" & _
                  ", nLastPrce" & _
                  ", nDealrPrc" & _
                  ", nMinDownx" & _
                  ", sMCCatIDx" & _
                  ", sModified" & _
                  ", dModified )" & _
                  " ( SELECT" & _
                     "  sModelIDx" & _
                     ", dPricexxx" & _
                     ", nPurPrice" & _
                     ", nSelPrice" & _
                     ", nLastPrce" & _
                     ", nDealrPrc" & _
                     ", nMinDownx" & _
                     ", sMCCatIDx" & _
                     ", sModified" & _
                     ", dModified" & _
                  " FROM MC_Model_Price" & _
                  " WHERE sModelIDx = " & strParm(p_oDetail("sModelIDx")) & _
                     " AND dPricexxx = " & dateParm(p_oDetail("dPricexxx")) & " )"
   
      If p_oAppDrivr.Execute(lsSQL, "MC_Model_Price_History") <= 0 Then
         MsgBox "Unable to Insert Record to History!", vbCritical, "Warning"
         GoTo endProc
      End If
   End If
   
   ' now update the current pricelist
   lsSQL = "UPDATE MC_Model_Price SET" & _
               "  sModelIDx = " & strParm(p_oDetail("sModelIDx")) & _
               ", dPricexxx = " & dateParm(p_dPricexxx) & _
               ", nSelPrice = " & p_oDetail("nSelPrice") & _
               ", nLastPrce = " & p_oDetail("nLastPrce") & _
               ", nDealrPrc = " & p_oDetail("nDealrPrc") & _
               ", sMCCatIDx = " & strParm(p_sMCCatIDx) & _
               ", cRecdStat = " & strParm(xeRecStateActive) & _
               ", sModified = " & strParm(p_oAppDrivr.UserID) & _
               ", dModified = " & dateParm(p_oAppDrivr.SysDate) & _
            " WHERE sModelIDx = " & strParm(p_oDetail("sModelIDx"))
            
   If p_oAppDrivr.Execute(lsSQL, "MC_Model_Price") <= 0 Then
      MsgBox "Unable to Update Price to Info!", vbCritical, "Warning"
      GoTo endProc
   End If

   updateMCCategory = True

endProc:
   Exit Function
errProc:
   ShowError lsProcName & "( " & " )"
End Function

Private Sub ShowError(ByVal lsProcName As String)
   With p_oAppDrivr
      .xLogError Err.Number, Err.Description, pxeMODULENAME, lsProcName, Erl
   End With
   With Err
      .Raise .Number, .Source, .Description
   End With
End Sub


