object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'File Hash'
  ClientHeight = 337
  ClientWidth = 635
  Color = clBtnFace
  Constraints.MinHeight = 240
  Constraints.MinWidth = 570
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    635
    337)
  PixelsPerInch = 96
  TextHeight = 16
  object Label1: TLabel
    Left = 295
    Top = 61
    Width = 37
    Height = 16
    Caption = 'Label1'
  end
  object Label2: TLabel
    Left = 295
    Top = 75
    Width = 37
    Height = 16
    Caption = 'Label2'
  end
  object JvgProgress1: TJvgProgress
    Left = 8
    Top = 303
    Width = 619
    Height = 26
    BevelInner = bvNone
    Colors.Delineate = clGray
    Colors.Shadow = clBlack
    Colors.Background = clBlack
    Gradient.FromColor = clGreen
    Gradient.ToColor = clGreen
    Gradient.Active = True
    Gradient.Orientation = fgdVertical
    Gradient.PercentFilling = 50
    GradientBack.FromColor = clMaroon
    GradientBack.ToColor = clMaroon
    GradientBack.Active = False
    GradientBack.Orientation = fgdVertical
    Percent = 50
    CaptionAlignment = taCenter
    Interspace = 0
    Options = []
    Anchors = [akLeft, akRight, akBottom]
    Caption = 'Progress...[%d%%]'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -13
    Font.Name = 'Tahoma'
    Font.Style = []
  end
  object JvFilenameEdit1: TJvFilenameEdit
    Left = 8
    Top = 8
    Width = 619
    Height = 24
    TabOrder = 0
    Text = ''
    OnChange = JvFilenameEdit1Change
  end
  object CheckListBox1: TCheckListBox
    Left = 8
    Top = 38
    Width = 281
    Height = 51
    OnClickCheck = CheckListBox1ClickCheck
    BevelInner = bvNone
    BevelOuter = bvNone
    BorderStyle = bsNone
    Columns = 3
    Flat = False
    Items.Strings = (
      'CRC32'
      'MD5'
      'SHA1'
      'SHA224'
      'SHA256'
      'SHA384'
      'SHA512'
      'SHA512_224'
      'SHA512_256')
    ParentColor = True
    TabOrder = 1
  end
  object Button1: TButton
    Left = 552
    Top = 38
    Width = 75
    Height = 25
    Caption = 'Get hash'
    TabOrder = 2
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 471
    Top = 38
    Width = 75
    Height = 25
    Caption = 'Continue'
    Enabled = False
    TabOrder = 3
    OnClick = Button2Click
  end
  object CheckBox1: TCheckBox
    Left = 295
    Top = 38
    Width = 90
    Height = 17
    Caption = 'Uppercase'
    TabOrder = 4
    OnClick = CheckBox1Click
  end
  object ListView1: TListView
    Left = 8
    Top = 95
    Width = 619
    Height = 202
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <
      item
        Caption = 'Hash'
        Width = 85
      end
      item
        Caption = 'Value'
        Width = 500
      end>
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    GridLines = True
    MultiSelect = True
    ReadOnly = True
    RowSelect = True
    ParentFont = False
    PopupMenu = PopupMenu1
    TabOrder = 5
    ViewStyle = vsReport
    OnContextPopup = ListView1ContextPopup
  end
  object PopupMenu1: TPopupMenu
    Left = 32
    Top = 120
    object SelectAll1: TMenuItem
      Caption = 'Select all'
      ShortCut = 16449
      OnClick = SelectAll1Click
    end
    object ReverseSelect1: TMenuItem
      Caption = 'Reverse select'
      ShortCut = 16466
      OnClick = ReverseSelect1Click
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object CopyValue1: TMenuItem
      Caption = 'Copy value'
      ShortCut = 16451
      OnClick = CopyValue1Click
    end
    object N2: TMenuItem
      Caption = '-'
    end
    object Compare1: TMenuItem
      Caption = 'Compare'
      ShortCut = 16454
      OnClick = Compare1Click
    end
  end
  object Timer1: TTimer
    Enabled = False
    OnTimer = Timer1Timer
    Left = 88
    Top = 120
  end
  object JvThread1: TJvThread
    Exclusive = True
    MaxCount = 0
    RunOnCreate = False
    FreeOnTerminate = True
    OnBegin = JvThread1Begin
    OnExecute = JvThread1Execute
    OnFinishAll = JvThread1FinishAll
    Left = 136
    Top = 120
  end
  object JvThread2: TJvThread
    Exclusive = False
    MaxCount = 0
    RunOnCreate = False
    FreeOnTerminate = True
    OnExecute = JvThread2Execute
    Left = 192
    Top = 120
  end
end
