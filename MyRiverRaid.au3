;~ controle de teclado
;~ C:\Dropbox\AutoIt\BROL\temp_07.au3
;~ C:\Dropbox\BORIUS\key_press_01.au3

; #FUNCTION# ====================================================================================================================
; Name ..........: MyRiverRaid
; Author ........: Luigi (Luismar Chechelaky)
; Description ...: um simples exemplo utilizando IrrLitch para renderizar um avião movendo-se por um mapa finito em loop infinito.
;                  O mapa foi construído com o Tiled Map Editor e o código traduz imagens 2d em seu equivalente em 3D.
; Link ..........: https://github.com/chechelaky/MyRiverRaid/
;
; Q muda a camera (3 ângulos)
; T sobe
; G desce
; setas (cima, baixo, esquerda, direita) movimento
; ===============================================================================================================================

#include-once
#include <Array.au3>
#include <File.au3>
#include <String.au3>
#include <Misc.au3>

#include <au3Irrlicht2.au3>
#include <include/JSMN.au3>
#include <include/object_dump.au3>

OnAutoItExitRegister("_quit")

HotKeySet("{ESC}", "_quit")

Global $hDLL = DllOpen("user32.dll")
Global $aKeys[5][9] = [ _
		[8], _ ; quantidade de elementos do array
		[25, 26, 27, 28, 41, 53, 44, 47, 54], _ ; teclas a serem utilizadas
		[1, 1, 1, 1, 1, 1, 1, 1, 1], _ ; estado das teclas: 1 não pressionada, 9 presssionada
		[0, 0, 0, 0, 100, 200, 300, 400, 400], _ ; delay de reutilização das teclas
		[0, 0, 0, 0, TimerInit(), TimerInit(), TimerInit(), TimerInit(), TimerInit()] _ ; momento da última utilização
		]

Global $oMAP
Global Const $cHEIG = "height", $cWIDT = "width", $cIMGH = "imageheight", $cIMGW = "imagewidth", $cTILW = "tilewidth", $cTILH = "tileheight"
Global Const $cFIRG = "firstgid", $cMESH = "mesh", $cLAYE = "layers", $cDATA = "data", $cNAME = "name", $cTLPR = "tileproperties", $cTLST = "tilesets"

Global Enum $xFILE = 0, $xMESH, $xNODE, $xTYPE, $xFLAG, $xPOSX, $xPOSY, $xPOSZ, $xSPED, $xUNKNOW, $xANGL
Global Const $TILE = 32
Global Const $ROOT = Round(Sqrt(2) / 2, 3)

Global $keyStruct
Global $h_Camera
Global $aCentro[3] = [0, 0, 0]
Global $aPista[5][12]
Global $iPasso = UBound($aPista, 2) - 1
Global $A_DOT[1][1][1]
Global $dy = 0
Global $ii, $jj
Global $iVertical = 0, $iSobeDesce = 0
Global $aCamPos[4][3] = [[1], [0, 0, 0], [0, 100, 0], [0, 250, 0]]

HotKeySet("q", "ChangeCam")

Func ChangeCam()
	$aCamPos[0][0] += 1
	If $aCamPos[0][0] >= UBound($aCamPos, 1) Then $aCamPos[0][0] = 1
EndFunc   ;==>ChangeCam

Global $a_ACTOR[1][12] = [["objects/wair_plane_2.obj", 0, 0, 0, 0, 0, 0, -96, 0.3, 0]]
$a_ACTOR[0][9] = $a_ACTOR[0][8] * $ROOT
$iVertical = $a_ACTOR[0][6]
Global $aSmoke[4]

;~ _ArrayDisplay($a_ACTOR, "$a_ACTOR", "", 0, "", "$xFILE|$xMESH|$xNODE|$xTYPE|$xFLAG|$xPOSX|$xPOSY|$xPOSZ|$xSPED|$xUNKNOW|$xANGL")

Global $aMesh[1][1]
MAP_Load(@ScriptDir & "/pista.json")

_IrrStartAdvanced( _
		$IRR_EDT_OPENGL, _ ;     $IRR_EDT_DIRECT3D8, $IRR_EDT_DIRECT3D9, $IRR_EDT_OPENGL
		1366, _
		768, _
		$IRR_BITS_PER_PIXEL_32, _ ; $IRR_BITS_PER_PIXEL_16, $IRR_BITS_PER_PIXEL_32
		$IRR_WINDOWED, _ ;          $IRR_WINDOWED, $IRR_FULLSCREEN
		$IRR_SHADOWS, _ ;        $IRR_NO_SHADOWS, $IRR_SHADOWS
		$IRR_CAPTURE_EVENTS, _ ;    $IRR_IGNORE_EVENTS, $IRR_CAPTURE_EVENTS
		$IRR_VERTICAL_SYNC_ON, _ ; $IRR_VERTICAL_SYNC_OFF, $IRR_VERTICAL_SYNC_ON
		0, _
		$IRR_ON, _ ;                $IRR_ON, $IRR_OFF
		16, _ ;                     2, 4, 8, 16
		$IRR_OFF _
		)

Global $hFont = _IrrGetFont("media/DOSLike.bmp")

$h_Camera = _IrrAddCamera(0, 97, -174, 0, -61, -51)
;~ $h_Camera = _IrrAddFPSCamera( _
;~ 		0, _ ; $h_ParentNode
;~ 		100.0, _ ; $f_RotateSpeed
;~ 		0.05, _ ; $f_MoveSpeed
;~ 		 - 1, _ ; $i_ID
;~ 		__CreatePtrKeyMapArray($keyStruct, $KEY_KEY_W, $KEY_KEY_S, $KEY_KEY_A, $KEY_KEY_D, $KEY_SPACE), _ ; $h_KeyMapArray
;~ 		5, _ ; $i_KeyMapSize
;~ 		0, _ ; $i_NoVerticalMovement
;~ 		0 _ ; $f_JumpSpeed
;~ 		)
;~ $keyStruct = 0

ReDim $A_DOT[UBound($aPista, 1)][UBound($aPista, 2)][8]

Global $aLim[4] = [ _
		$aCentro[0] - $TILE * UBound($aPista, 1) / 2, _
		$aCentro[1] - $TILE * UBound($aPista, 2) / 2 _
		]
$aLim[2] = $aLim[0] + 16
$aLim[3] = $aLim[0] - 16 + $TILE * UBound($aPista, 1)

$a_ACTOR[0][$xMESH] = _IrrGetMesh($a_ACTOR[0][$xFILE])
_IrrSetMeshHardwareAccelerated($a_ACTOR[0][$xMESH])

$a_ACTOR[0][$xNODE] = _IrrAddMeshToScene($a_ACTOR[0][$xMESH])
_IrrSetNodePosition($a_ACTOR[0][$xNODE], $a_ACTOR[0][$xPOSX], $a_ACTOR[0][$xPOSY], $a_ACTOR[0][$xPOSZ])
_IrrSetNodeMaterialFlag($a_ACTOR[0][$xNODE], $IRR_EMF_LIGHTING, $IRR_OFF)

_IrrSetNodePosition($h_Camera, 0, 97, -174)
_IrrSetCameraTarget($h_Camera, 0, -61, -51)
Global $aPasso[5] = [0, 19, 0, 0, UBound($aMesh, 1) - 1]

For $kk = 0 To UBound($aPista, 2) - 2
	Adiciona()
Next

Global $aTimer[2][3] = [[TimerInit(), TimerInit(), TimerInit()], [12, 12, 12]]
Global $iFumaca = 0
;~ Global $hFumaca = _IrrAddParticleSystemToScene($IRR_NO_EMITTER)

Global $hFumaca
Global $hFumacaParticula = __CreateParticleSettings( _
		 - 0.5, -0.5, -1.5, _	; min_box_x / min_box_y / min_box_z
		0.5, 0.5, 2.5, _	; max_box_x / max_box_y / max_box_z
		0, 0, -0.1, _		; direction_x / direction_y / direction_z
		400, 800, _			; min_paritlcles_per_second / max_paritlcles_per_second
		255, 255, 255, _	; min_start_color_red / min_start_color_green / min_start_color_blue
		255, 255, 255, _	; max_start_color_red / max_start_color_green / max_start_color_blue
		20, 100, _		; min_lifetime / max_lifetime
		2.0, 2.0, _		; min_start_sizeX / min_start_sizeY
		3.0, 3.0, _		; max_start_sizeX / max_start_sizeY
		7) ; max_angle_degrees

Global $hFumacaTextura = _IrrGetTexture("media/ParticleGrey.bmp")


While _IrrRunning()
	If TimerDiff($aTimer[0][1]) > $aTimer[1][1] - 5 Then
		_IrrBeginScene(127, 127, 127)
		_IrrDrawScene()
		_GAME_MovePlayer(1)
		$dy += 0.4
		If $dy + 352 >= $aPasso[0] Then Adiciona()
		If $dy >= $aPasso[1] Then Remove()

		_IrrSetNodePosition($h_Camera, $aCamPos[$aCamPos[0][0]][1], 32, $dy - 149)
		_IrrSetCameraTarget($h_Camera, 0, 16, $dy)

		_Irr2DFontDraw($hFont, "FPS       [ " & _IrrGetFPS() & " ]", 10, 10, 250, 96)
		_Irr2DFontDraw($hFont, "DISTÂNCIA [ " & StringFormat("%.2f", $dy) & " ]", 10, 30, 250, 96)
		_Irr2DFontDraw($hFont, "Altitude  [ " & StringFormat("%.2f", $a_ACTOR[0][$xPOSY]) & " ]", 10, 50, 250, 96)
		_IrrEndScene()
		$aTimer[0][1] = TimerInit()
	EndIf
WEnd

Func _GAME_MovePlayer($ID = 0)
	If Not $ID Then Return
	For $ii = 0 To $aKeys[0][0]
		$aKeys[2][$ii] = _IsPressed($aKeys[1][$ii], $hDLL) ? 9 : 1
	Next
	Switch $aKeys[2][0] & $aKeys[2][1] & $aKeys[2][2] & $aKeys[2][3]
		Case 9111 ; Esquerda
			$a_ACTOR[0][$xPOSX] -= $a_ACTOR[0][8]
			If $a_ACTOR[0][$xPOSX] < $aLim[2] Then $a_ACTOR[0][$xPOSX] = $aLim[2]
			If $a_ACTOR[0][$xANGL] < 30 Then $a_ACTOR[0][$xANGL] += 1
		Case 1911 ; Frente
			$dy += $a_ACTOR[0][8]
		Case 1191 ; Direita
			$a_ACTOR[0][$xPOSX] += $a_ACTOR[0][8]
			If $a_ACTOR[0][$xPOSX] > $aLim[3] Then $a_ACTOR[0][$xPOSX] = $aLim[3]
			If $a_ACTOR[0][$xANGL] > -30 Then $a_ACTOR[0][$xANGL] -= 1
		Case 1119 ; Tráz
			$dy -= 0.075
		Case 9911 ; Frente-Esquerda
			$dy += $a_ACTOR[0][8]
			$a_ACTOR[0][$xPOSX] -= $a_ACTOR[0][9]
			If $a_ACTOR[0][$xPOSX] < $aLim[2] Then $a_ACTOR[0][$xPOSX] = $aLim[2]
			If $a_ACTOR[0][$xANGL] < 30 Then $a_ACTOR[0][$xANGL] += 1
		Case 1991 ; Frente-Direita
			$dy += $a_ACTOR[0][8]
			$a_ACTOR[0][$xPOSX] += $a_ACTOR[0][9]
			If $a_ACTOR[0][$xPOSX] > $aLim[3] Then $a_ACTOR[0][$xPOSX] = $aLim[3]
			If $a_ACTOR[0][$xANGL] > -30 Then $a_ACTOR[0][$xANGL] -= 1
		Case 1199 ; Tráz-Direita
			$dy -= 0.075
			$a_ACTOR[0][$xPOSX] += $a_ACTOR[0][9]
		Case 9119 ; Tráz-Esquerda
			$dy -= 0.075
			$a_ACTOR[0][$xPOSX] -= $a_ACTOR[0][9]
		Case Else

	EndSwitch

	If $aKeys[2][1] = 1 Then
		If $iFumaca Then
			_IrrRemoveNode($hFumaca)
			$iFumaca = 0
		EndIf
	Else
		If Not $iFumaca Then
			$hFumaca = _IrrAddParticleSystemToScene($IRR_NO_EMITTER)
			_IrrAddParticleEmitter($hFumaca, $hFumacaParticula)
			_IrrSetNodeMaterialTexture($hFumaca, $hFumacaTextura, 0)
			_IrrSetNodeMaterialFlag($hFumaca, $IRR_EMF_LIGHTING, $IRR_OFF)
			_IrrSetNodeMaterialType($hFumaca, $IRR_EMT_TRANSPARENT_VERTEX_ALPHA)

			$iFumaca = 1
		EndIf
	EndIf

	If $aKeys[2][8] = 9 And TimerDiff($aKeys[4][7]) > $aKeys[3][7] Then _GAME_Player_MoveUp()
	If $aKeys[2][7] = 9 And TimerDiff($aKeys[4][8]) > $aKeys[3][8] Then _GAME_Player_MoveDown()


	If $iVertical = $a_ACTOR[0][$xPOSY] Then

	Else
		If $iVertical > $a_ACTOR[0][$xPOSY] Then
			If $iSobeDesce >= -20 Then $iSobeDesce -= 0.5
			$a_ACTOR[0][$xPOSY] += 0.1
			If $a_ACTOR[0][$xPOSY] > $iVertical Then $a_ACTOR[0][$xPOSY] = $iVertical
		EndIf
		If $iVertical < $a_ACTOR[0][$xPOSY] Then
			If $iSobeDesce <= 20 Then $iSobeDesce += 0.5
			$a_ACTOR[0][$xPOSY] -= 0.1
			If $a_ACTOR[0][$xPOSY] < $iVertical Then $a_ACTOR[0][$xPOSY] = $iVertical
		EndIf
	EndIf

	If $iVertical = $a_ACTOR[0][$xPOSY] Then
		If $iSobeDesce > 0 Then
			$iSobeDesce -= 0.75
			If $iSobeDesce < 0 Then $iSobeDesce = 0
		EndIf
		If $iSobeDesce < 0 Then
			$iSobeDesce += 0.75
			If $iSobeDesce > 0 Then $iSobeDesce = 0
		EndIf
	EndIf

	If $aKeys[2][0] = 1 And $aKeys[2][2] = 1 Then
		If $a_ACTOR[0][$xANGL] > 0 Then
			$a_ACTOR[0][$xANGL] -= 1
			If $a_ACTOR[0][$xANGL] < 0 Then $a_ACTOR[0][$xANGL] = 0
		Else
			$a_ACTOR[0][$xANGL] += 1
			If $a_ACTOR[0][$xANGL] > 0 Then $a_ACTOR[0][$xANGL] = 0
		EndIf
	EndIf

	If $a_ACTOR[0][$xPOSZ] < $dy - 96 Then $a_ACTOR[0][$xPOSZ] = $dy - 96
	_IrrSetNodeRotation($a_ACTOR[0][$xNODE], $iSobeDesce, 0, $a_ACTOR[0][$xANGL])
	_IrrSetNodePosition($a_ACTOR[0][$xNODE], $a_ACTOR[0][$xPOSX], $a_ACTOR[0][$xPOSY], $a_ACTOR[0][$xPOSZ])

	If $iFumaca Then _IrrSetNodePosition($hFumaca, $a_ACTOR[0][$xPOSX], $a_ACTOR[0][$xPOSY], $a_ACTOR[0][$xPOSZ] - 12)

	If Not $aSmoke[0] And $iFumaca Then
		$aSmoke[1] = $a_ACTOR[0][$xPOSX]
		$aSmoke[2] = $a_ACTOR[0][$xPOSY]
		$aSmoke[3] = $a_ACTOR[0][$xPOSZ]
		$aSmoke[0] = 20
		_IrrAddParticleAttractionAffector($hFumaca, $a_ACTOR[0][$xPOSX], $a_ACTOR[0][$xPOSY], $a_ACTOR[0][$xPOSZ], 2, $IRR_ATTRACT, 0, 0, 2)
	EndIf
	$aSmoke[0] -= 1
EndFunc   ;==>_GAME_MovePlayer

Func _GAME_Player_MoveUp()
	$iVertical += 8
	$aKeys[4][7] = TimerInit()
EndFunc   ;==>_GAME_Player_MoveUp

Func _GAME_Player_MoveDown()
	$iVertical -= 8
	$aKeys[4][8] = TimerInit()
EndFunc   ;==>_GAME_Player_MoveDown

Func Adiciona()
	For $ii = 0 To UBound($aPista, 1) - 1
		$A_DOT[$ii][$aPasso[2]][$xMESH] = _IrrGetMesh($aMesh[$aPasso[4]][$ii])
		_IrrSetMeshHardwareAccelerated($A_DOT[$ii][$aPasso[2]][$xMESH])
		$A_DOT[$ii][$aPasso[2]][$xNODE] = _IrrAddMeshToScene($A_DOT[$ii][$aPasso[2]][$xMESH])
		_IrrSetNodePosition($A_DOT[$ii][$aPasso[2]][$xNODE], $aLim[0] + $ii * $TILE + 16, 0, $aPasso[0] - 176)
		_IrrSetNodeMaterialFlag($A_DOT[$ii][$aPasso[2]][$xNODE], $IRR_EMF_LIGHTING, $IRR_OFF)
	Next
	$aPasso[2] += 1
	If $aPasso[2] > $iPasso Then $aPasso[2] = 0
	$aPasso[4] -= 1
	If $aPasso[4] < 0 Then $aPasso[4] = UBound($aMesh, 1) - 1
	$aPasso[0] += 32
EndFunc   ;==>Adiciona

Func Remove()
	For $ii = 0 To UBound($aPista, 1) - 1
		_IrrRemoveNode($A_DOT[$ii][$aPasso[3]][$xNODE])
	Next
	$aPasso[1] += 32
	$aPasso[3] += 1
	If $aPasso[3] > $iPasso Then $aPasso[3] = 0
EndFunc   ;==>Remove

Func _quit()
	_IrrStop()
	If $hDLL Then DllClose($hDLL)
EndFunc   ;==>_quit

Func _Num($iNum = 0, $iBefore = 5, $iAfter = 3)
	Local $aRet[2], $iLen
	If StringInStr($iNum, ".") Then
		Local $aNum = StringSplit($iNum, ".", 2)
		$aRet[0] = _StringRepeat(" ", $iBefore - StringLen($aNum[0])) & $aNum[0]
		$iLen = StringLen($aNum[1])
		If $iLen = $iAfter Then
			$aRet[1] = $aNum[1]
		Else
			If $iLen > $iAfter Then
				$aRet[1] = StringMid($aNum[1], 1, $iAfter)
			Else
				$aRet[1] = $aNum[1] & _StringRepeat(0, $iAfter - $iLen)
			EndIf
		EndIf
	Else
		$aRet[0] = _StringRepeat(" ", $iBefore - StringLen($iNum)) & $iNum
		$aRet[1] = _StringRepeat(0, $iAfter)
	EndIf
	Return $aRet[0] & "." & $aRet[1]
EndFunc   ;==>_Num

Func MAP_Load($sMap = 0)
	If Not $sMap Then Return SetError(1, 0, 0)
	$sMap = _PathFull($sMap, @ScriptDir)
	If Not FileExists($sMap) Then Return SetError(2, 0, 0)
	$oMAP = json_load($sMap)
	If $oMAP = Default Then Return SetError(3, 0, 0)

	ReDim $aMesh[$oMAP.Item($cHEIG)][$oMAP.Item($cWIDT)]

	Local $oTileSet = _MAP_Get_TileSetProperties()

	Local $aTiles, $xx, $yy
	For $each In $oMAP.Item($cLAYE)
		$xx = 0
		$yy = 0
		$sName = $each.Item($cNAME)
		$aTiles = $each.Item($cDATA)
		For $ii = 0 To UBound($aTiles, 1) - 1
			If $oTileSet.Item(Number($aTiles[$ii])) Then $aMesh[$xx][$yy] = $oTileSet.Item(Number($aTiles[$ii]))
			$yy += 1
			If $yy = $oMAP.Item($cWIDT) Then
				$yy = 0
				$xx += 1
			EndIf
		Next
	Next
EndFunc   ;==>MAP_Load

Func _MAP_Get_TileSetProperties()
	Local $oRet = ObjCreate($SD)
	Local $oo
	Local $aTile = $oMAP.Item($cTLST)
	Local $oProperties
	Local $iNext
	Local $sFilePath
	Local $sFileDefault = _PathFull("objects\default.obj", @ScriptDir)

	For $ii = 0 To UBound($aTile, 1) - 1
		$oo = ObjCreate($SD)
		$oProperties = ($aTile[$ii]).Item($cTLPR)
		$iNext = 0
		For $xx = 0 To ($aTile[$ii]).Item($cIMGH) / ($aTile[$ii]).Item($cTILH) - 1
			For $yy = 0 To ($aTile[$ii]).Item($cIMGW) / ($aTile[$ii]).Item($cTILW) - 1
				$sFilePath = _PathFull("objects\" & $oProperties.Item(String($iNext)).Item($cMESH), @ScriptDir)
				If $oProperties.Exists(String($iNext)) And FileGetAttrib($sFilePath) = "A" And FileExists($sFilePath) Then
					$oRet.Add(Number($iNext + ($aTile[$ii]).Item($cFIRG)), $sFilePath)
				Else
					$oRet.Add(Number($iNext + ($aTile[$ii]).Item($cFIRG)), $sFileDefault)
				EndIf
				$iNext += 1
			Next
		Next
	Next
	Return $oRet
EndFunc   ;==>_MAP_Get_TileSetProperties
