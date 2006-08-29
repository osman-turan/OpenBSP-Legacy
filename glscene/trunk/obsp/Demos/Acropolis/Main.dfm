object FormMain: TFormMain
  Left = 192
  Top = 114
  Width = 520
  Height = 418
  Caption = 'Acropolis'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnKeyUp = FormKeyUp
  PixelsPerInch = 96
  TextHeight = 13
  object GLSceneRenderer: TGLSceneViewer
    Left = 0
    Top = 0
    Width = 512
    Height = 384
    Camera = SceneCamera
    Buffer.FogEnvironment.FogColor.Color = {0000803F0000803F0000803F0000803F}
    Buffer.FogEnvironment.FogStart = 10.000000000000000000
    Buffer.FogEnvironment.FogEnd = 4096.000000000000000000
    Buffer.FogEnvironment.FogDistance = fdEyeRadial
    Buffer.BackgroundColor = clWhite
    Buffer.Lighting = False
    Align = alClient
    OnMouseDown = GLSceneRendererMouseDown
    OnMouseMove = GLSceneRendererMouseMove
  end
  object GLSceneEngine: TGLScene
    Left = 6
    Top = 4
    object GLSkyBox1: TGLSkyBox
      Direction.Coordinates = {000000000000803F0000000000000000}
      Up.Coordinates = {00000000000000000000803F00000000}
      MaterialLibrary = GenericMaterials
      MatNameTop = 'textures/clouds'
      MatNameBottom = 'textures/clouds'
      MatNameLeft = 'textures/clouds'
      MatNameRight = 'textures/clouds'
      MatNameFront = 'textures/clouds'
      MatNameBack = 'textures/clouds'
      CloudsPlaneOffset = 32.000000000000000000
      CloudsPlaneSize = 1024.000000000000000000
    end
    object MapRenderer: TGLFreeForm
      MaterialLibrary = MapMaterials
      LightmapLibrary = Lightmaps
    end
    object sky_base: TGLPlane
      Material.MaterialLibrary = GenericMaterials
      Material.LibMaterialName = 'textures/clouds'
      Position.Coordinates = {0000000000000000000000440000803F}
      Up.Coordinates = {000000000000803F0000008000000000}
      Visible = False
      OnProgress = sky_baseProgress
      Height = 16384.000000000000000000
      Width = 16384.000000000000000000
      XTiles = 5
      YTiles = 5
      Style = [psTileTexture]
      NoZWrite = False
    end
    object sky_add: TGLPlane
      Material.MaterialLibrary = GenericMaterials
      Material.LibMaterialName = 'textures/clouds'
      Position.Coordinates = {00000000000000000000FA430000803F}
      Up.Coordinates = {000000000000803F0000008000000000}
      Visible = False
      OnProgress = sky_addProgress
      Height = 16384.000000000000000000
      Width = 16384.000000000000000000
      XTiles = 5
      YTiles = 5
      Style = [psTileTexture]
      NoZWrite = False
    end
    object SceneCamera: TGLCamera
      DepthOfView = 100.000000000000000000
      FocalLength = 90.000000000000000000
      CameraStyle = csInfinitePerspective
      Direction.Coordinates = {000000000000803F0000008000000000}
      Up.Coordinates = {00000000000000000000803F00000000}
    end
  end
  object GLCadencer1: TGLCadencer
    Scene = GLSceneEngine
    OnProgress = GLCadencer1Progress
    Left = 38
    Top = 4
  end
  object MapMaterials: TGLMaterialLibrary
    Left = 70
    Top = 4
  end
  object GenericMaterials: TGLMaterialLibrary
    Materials = <
      item
        Name = 'textures/clouds'
        Material.FrontProperties.Diffuse.Color = {0000803F0000803F0000803F0000003F}
        Material.BlendingMode = bmTransparency
        Material.MaterialOptions = [moIgnoreFog]
        Material.Texture.Compression = tcNone
        Material.Texture.FilteringQuality = tfAnisotropic
        Material.Texture.Disabled = False
        Material.FaceCulling = fcNoCull
        Tag = 0
      end>
    Left = 102
    Top = 4
  end
  object Lightmaps: TGLMaterialLibrary
    Left = 136
    Top = 2
  end
end
