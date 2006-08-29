//
// This unit is part of the GLScene Project, http://glscene.org
//
{: GLFileOBSP<p>

    Support-code to load OpenBSP Files into TGLFreeForm-Components in GLScene.<p>
    Note that you must manually add this unit to one of your project's uses
    to enable support for OpenBSP at run-time.<p>

    VERY IMPORTANT NOTE:
      If you have downloaded newer alpha version of OpenBSP compiler,
      you may not use this unit. Because, file version will be 1.0
      until public release.

	<b>History : </b><font size=-1><ul>
           <li>05/02/04 - OT - Fixed loading problem
                               Added vertex lighting for triangle meshes
	   <li>03/08/04 - OT - Creation
  </ul><p>
}
unit GLFileOBSP;

interface

uses Classes, GLVectorFileObjects, ApplicationFileIO, GLMisc;

type
   // TGLOBSPVectorFile
   //
   {: The OBSP vector file (OpenBSP).<p> }
   TGLOBSPVectorFile = class(TVectorFile)
      public
         { Public Declarations }
         class function Capabilities : TDataFileCapabilities; override;

         procedure LoadFromStream(aStream: TStream); override;
   end;

var
   // OBSP lightmaps can be quite dark, we brighten them a lot by a bit
   vOBSPLightmapGammaCorrection : Single = 1.5;
   vOBSPLightmapBrightness : Single = 1;   // scaling factor, 1.0 = unchanged
   vGLFileOBSPLoadMaterials : boolean = True; // Mrqzzz : Flag to avoid loading materials (useful for IDE Extentions like GlaredX)
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
implementation
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------

uses Graphics, SysUtils, GLGraphics, GLTexture, GLBSP,
GLUtils, VectorGeometry, obspMapLoader, obspFile;

// ------------------
// ------------------ TGLOBSPVectorFile ------------------
// ------------------

// Capabilities
//
class function TGLOBSPVectorFile.Capabilities : TDataFileCapabilities;
begin
   Result:=[dfcRead];
end;

// LoadFromStream
//
procedure TGLOBSPVectorFile.LoadFromStream(aStream : TStream);
//type
 // T24bit=array[0..2] of byte;

const
  cInv255 = 1/255;


   function LocateTextureFile(const texName : String) : String;
   begin
      if FileStreamExists(texName+'.bmp') then
         Result:=texName+'.bmp'
      else if FileStreamExists(texName+'.jpg') then
         Result:=texName+'.jpg'
      else if FileStreamExists(texName+'.tga') then
         Result:=texName+'.tga'
      else Result:='';
   end;

   function GetOrAllocateMaterial(const matName : String): String;
   var
      matLib : TGLMaterialLibrary;
      libMat : TGLLibMaterial;
      texName : String;
   begin
      if GetOwner is TGLBaseMesh then begin
         // got a linked material library?
         matLib:=TGLBaseMesh(GetOwner).MaterialLibrary;
         if Assigned(matLib) then begin
            Result:=matName;
            libMat:=matLib.Materials.GetLibMaterialByName(matName);
            if not Assigned(libMat) then begin
               if Pos('.', matName)<1 then begin
                  texName:=LocateTextureFile(matName);
                  if texName='' then
                     texName:=LocateTextureFile(Copy(matName, LastDelimiter('\/', matName)+1, MaxInt));
               end else texName:=matName;
               with matLib.AddTextureMaterial(matName, texName) do begin
                  Material.Texture.TextureMode:=tmModulate;
               end;
            end;
         end else Result:='';
      end else Result:='';
   end;

var
  obsp: TOBSPMap;
  i, j, k, n, y: Integer;
  lightmapBmp: TBitmap;
 // lightmapBmp: TGLBitmap32;
  bmp:TBitmap;
  lightmapLib: TGLMaterialLibrary;
 // bspLightMap: TByteArray;//PByteArray;
  libMat: TGLLibMaterial;
  mo: TBSPMeshObject;
  color: TVector;
  v: TAffineVector;
  t: TTexPoint;
  fg, lastfg : TFGBSPNode;
  surfPtr: ^TOBSPSurface;
  offset:integer;
  light:byte;
begin
  obsp := TOBSPMap.Create;
  if not obsp.LoadFromStream(aStream) then Exit;

  try
    mo:=TBSPMeshObject.CreateOwned(Owner.MeshObjects);

    if vGLFileOBSPLoadMaterials then
    begin
    // load materials
      for i:=0 to obsp.MaterialCount-1 do
        GetOrAllocateMaterial(obsp.Materials[i]);
    end;

  // import all lightmaps
    lightmapLib:=Owner.LightmapLibrary;
    if Assigned(lightmapLib) and vGLFileOBSPLoadMaterials then
    begin
    // import lightmaps
      try

        for i:=0 to obsp.LightmapCount-1 do
        begin
        lightmapBmp:=TBitmap.Create;
        lightmapBmp.Width:=obsp.LightmapWidth;
        lightmapBmp.Height:=obsp.LightmapHeight;

        offset:=i *( obsp.LightmapWidth) * (obsp.LightmapHeight) * 3 ;

        for y:=0 to obsp.LightmapHeight-1 do
          for k:=0 to obsp.Lightmapwidth  -1 do
          begin
            light:=obsp.flightmaps[offset+((obsp.LightmapHeight-y)*3)*obsp.Lightmapheight+(k*3)];
            lightmapbmp.Canvas.Pixels[k,y]:=65536*light+256*light+light;
          end;

          libMat:=lightmapLib.AddTextureMaterial(IntToStr(i), lightmapbmp);
          with libMat.Material.Texture do
          begin
              MinFilter:=miLinear;
              TextureWrap:=twNone;
              TextureFormat:=tfRGB;

              
          end;
          lightmapBmp.Free;

        end;
      finally
      end;
    end;

  // read all vertices and convert them to GLScene geometry
    mo.Vertices.AdjustCapacityToAtLeast(obsp.VertexCount);
    mo.Normals.AdjustCapacityToAtLeast(obsp.VertexCount);
    mo.TexCoords.AdjustCapacityToAtLeast(obsp.VertexCount);
    mo.Colors.AdjustCapacityToAtLeast(obsp.VertexCount);

    for i:=0 to obsp.VertexCount-1 do
    begin
      v := AffineVectorMake(obsp.Vertices[i].Position[0],
                            obsp.Vertices[i].Position[1],
                            obsp.Vertices[i].Position[2]);
      mo.Vertices.Add(v);

      v := AffineVectorMake(obsp.Vertices[i].Normal[0],
                            obsp.Vertices[i].Normal[1],
                            obsp.Vertices[i].Normal[2]);
      mo.Normals.Add(v);

      t := TexPointMake(obsp.Vertices[i].TexCoord[0],
                        1-obsp.Vertices[i].TexCoord[1]);
      mo.TexCoords.Add(t);

      if Assigned(lightMapLib) and vGLFileOBSPLoadMaterials then
      begin
        t := TexPointMake(obsp.Vertices[i].LM_TexCoord[0],
                          obsp.Vertices[i].LM_TexCoord[1]);
        mo.LightMapTexCoords.Add(t);
      end;

    // identity lighting by default
      mo.Colors.Add(1, 1, 1, 1);
    end;

    // import vertex-lighting info for triangle mesh models
    for i:=0 to obsp.SurfaceCount-1 do
    begin
      if obsp.Surfaces[i].SurfaceType <> SURF_TYPE_MESH then Continue;

      for j:=0 to obsp.Surfaces[i].NumVertices-1 do
      begin
        n := obsp.Surfaces[i].FirstVertex + j;
        color := VectorMake(obsp.Vertices[n].Color[0] * cInv255,
                            obsp.Vertices[n].Color[1] * cInv255,
                            obsp.Vertices[n].Color[2] * cInv255,
                            1);
        mo.Colors.Items[n] := color;
      end;
    end;

    mo.RenderSort:=rsBackToFront;

  // OpenBSP separates tree nodes from leafy nodes, we don't,
  // so we place nodes first, then all leafs afterwards
    for i:=0 to obsp.NodeCount-1 do
    begin
      fg := TFGBSPNode.CreateOwned(mo.FaceGroups);
      fg.SplitPlane := VectorMake(obsp.Planes[obsp.Nodes[i].PlaneIndex].Normal[0],
                                  obsp.Planes[obsp.Nodes[i].PlaneIndex].Normal[1],
                                  obsp.Planes[obsp.Nodes[i].PlaneIndex].Normal[2],
                                  -obsp.Planes[obsp.Nodes[i].PlaneIndex].Dist);

      fg.PositiveSubNodeIndex := obsp.Nodes[i].FrontChild;
      if fg.PositiveSubNodeIndex < 0 then
         fg.PositiveSubNodeIndex := obsp.NodeCount - fg.PositiveSubNodeIndex - 1;

      Assert(fg.PositiveSubNodeIndex < obsp.NodeCount + obsp.LeafCount);
      Assert(fg.PositiveSubNodeIndex > 0);

      fg.NegativeSubNodeIndex := obsp.Nodes[i].BackChild;
      if fg.NegativeSubNodeIndex < 0 then
        fg.NegativeSubNodeIndex := obsp.NodeCount - fg.NegativeSubNodeIndex - 1;

      Assert(fg.NegativeSubNodeIndex < obsp.NodeCount + obsp.LeafCount);
      Assert(fg.NegativeSubNodeIndex > 0);
    end;

  // import all leaves
    for i:=0 to obsp.LeafCount-1 do
      TFGBSPNode.CreateOwned(mo.FaceGroups);

   // import all faces into leafs & subnodes
    for i:=0 to obsp.LeafCount-1 do
    begin
      lastfg := nil;
      for j:=0 to obsp.Leafs[i].NumSurfaces-1 do
      begin
        n := obsp.Leafs[i].FirstSurface + j;
        if n >= obsp.SurfaceCount then Break; // corrupted BSP?

        if (obsp.Surfaces[n].SurfaceType = SURF_TYPE_PLANAR) or
           (obsp.Surfaces[n].SurfaceType = SURF_TYPE_MESH) then
        begin
          if Assigned(lastfg) then
          begin
            lastfg.PositiveSubNodeIndex := mo.FaceGroups.Count;
            fg := TFGBSPNode.CreateOwned(mo.FaceGroups);
          end
          else
            fg := TFGBSPNode(mo.FaceGroups[i + obsp.NodeCount]);

         // check for BSP corruption
          if obsp.Surfaces[n].MaterialIndex <= Cardinal(obsp.MaterialCount) then
            fg.MaterialName := obsp.Materials[obsp.Surfaces[n].MaterialIndex];

          if Assigned(lightmapLib) and vGLFileOBSPLoadMaterials then
            fg.LightMapIndex := obsp.Surfaces[n].LightmapIndex;

          lastfg:=fg;

        // OBSP Polygon Faces are actually triangles (ordered clock-wise)
          fg.Mode := fgmmTriangles;
          for k:=(obsp.Surfaces[n].NumElements div 3)-1 downto 0 do
            fg.VertexIndices.Add(obsp.Surfaces[n].FirstVertex + obsp.Elements[obsp.Surfaces[n].FirstElement + k*3+2],
                                 obsp.Surfaces[n].FirstVertex + obsp.Elements[obsp.Surfaces[n].FirstElement + k*3+1],
                                 obsp.Surfaces[n].FirstVertex + obsp.Elements[obsp.Surfaces[n].FirstElement + k*3+0]);
        end;
      end;
    end;
  finally
    obsp.Free;
  end;

  // Some BSP end up with empty nodes/leaves (information unused, incorrept BSP...)
  // This call takes care of cleaning up all the empty nodes
  mo.CleanupUnusedNodes;
end;

// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
initialization
// ------------------------------------------------------------------
// ------------------------------------------------------------------
// ------------------------------------------------------------------
   RegisterVectorFileFormat('obsp', 'OpenBSP files', TGLOBSPVectorFile);

end.
