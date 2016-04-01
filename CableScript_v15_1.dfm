object CableGenForm: TCableGenForm
  Left = 117
  Top = 90
  BorderStyle = bsDialog
  Caption = 'CableGen'
  ClientHeight = 170
  ClientWidth = 216
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Microsoft Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object LabelTitle: TLabel
    Left = 8
    Top = 8
    Width = 93
    Height = 13
    Caption = 'Select scripts to run'
  end
  object LabelMapFields: TLabel
    Left = 8
    Top = 118
    Width = 3
    Height = 13
  end
  object CheckBoxGenerateBOM: TCheckBox
    Left = 18
    Top = 30
    Width = 180
    Height = 21
    Caption = 'Generate BOM'
    Checked = True
    State = cbChecked
    TabOrder = 1
    OnClick = CheckBoxGenerateBOMClick
  end
  object CheckBoxConnectionTable: TCheckBox
    Left = 18
    Top = 52
    Width = 180
    Height = 21
    Caption = 'Generate Connection Table'
    Checked = True
    State = cbChecked
    TabOrder = 2
    OnClick = CheckBoxConnectionTableClick
  end
  object CheckBoxCreateLabels: TCheckBox
    Left = 18
    Top = 74
    Width = 180
    Height = 21
    Caption = 'Generate Labels'
    Checked = True
    State = cbChecked
    TabOrder = 3
    OnClick = CheckBoxCreateLabelsClick
  end
  object CheckBoxHideComments: TCheckBox
    Left = 18
    Top = 96
    Width = 180
    Height = 21
    Caption = 'Hide Comments'
    Checked = True
    State = cbChecked
    TabOrder = 4
    OnClick = CheckBoxHideCommentsClick
  end
  object ButtonBegin: TButton
    Left = 8
    Top = 140
    Width = 200
    Height = 21
    Caption = 'Execute.'
    TabOrder = 0
    OnClick = ButtonBeginClick
  end
end
