%{
Este algoritmo permite modificar el ángulo objetivo con el joystick para 
que el ROV se coloque automáticamente mientras mantiene su altura.

Realizado por: Alejandro Garrocho Cruz. Octubre 2021.
%}

%% Obtención del puerto del ROV
capture_filter_MAVLINK = 'udp and dst port 14550';   
dissector = {'udp.srcport'};
interfaceID=1;
N_packets=1;

pcap_resultSrcPort2 = pcap2mat(capture_filter_MAVLINK,dissector, interfaceID, N_packets);
MavLinkPort=str2double(pcap_resultSrcPort2.udpsrcport);

%% Creación GCS con matlab y me suscribo al ROV
dialect = mavlinkdialect("common.xml", 1);

gcsNode = mavlinkio(dialect,'SystemID',255,'ComponentID',190,'AutopilotType',"MAV_AUTOPILOT_INVALID",'ComponentType',"MAV_TYPE_GCS"); 
gcsPort = 14550; 
connect(gcsNode,"UDP", 'LocalPort', gcsPort);

uavClient = mavlinkclient(gcsNode,1,1);

%% Mensajes que quiero recibir
%ATTITUDE
global Attitude Datos_Attitude 
Attitude = mavlinksub(gcsNode,uavClient, "ATTITUDE");
Datos_Attitude=struct('time_boot_ms',[],'roll',[],'pitch',[],'yaw',[],'rollspeed',[],'pitchspeed',[],'yawspeed',[]);

AttitudeTimer = timer('Period', 2,'ExecutionMode', 'fixedRate');
AttitudeTimer.TimerFcn = @(~,~)AttitudeCallback;
start(AttitudeTimer);

%GLOBAL POSITION INT
global GlobalPositionINT Datos_GlobalPositionINT
GlobalPositionINT = mavlinksub(gcsNode,uavClient, "GLOBAL_POSITION_INT");
Datos_GlobalPositionINT=struct('time_boot_ms',[],'lat',[],'lon',[],'alt',[],'relative_alt',[],'vx',[],'vy',[],'vz',[],'hdg',[]);

MessFreq=0.5;
GlobalPositionINTTimer = timer('Period', MessFreq,'ExecutionMode', 'fixedRate');

GlobalPositionINTTimer.TimerFcn = @(~,~)GlobalPositionINTCallback;
start(GlobalPositionINTTimer);

%BATTERY POWER
global SYS_STATUS
SYS_STATUS = mavlinksub(gcsNode,uavClient, "SYS_STATUS");

SYS_STATUSTimer = timer('Period', 60,'ExecutionMode', 'fixedRate');
SYS_STATUSTimer.TimerFcn = @(~,~)SYS_STATUSCallback;
start(SYS_STATUSTimer);

%NAMED_VALUE_FLOAT
NAMED_VALUE_FLOAT = mavlinksub(gcsNode,uavClient, "NAMED_VALUE_FLOAT", "BufferSize", 7);

%% Envío Heartbeat continuamente con timer
heartbeat = createmsg(dialect,"HEARTBEAT");
heartbeat.Payload.type(:) = enum2num(dialect,'MAV_TYPE',gcsNode.LocalClient.ComponentType); 
heartbeat.Payload.autopilot(:) = enum2num(dialect,'MAV_AUTOPILOT',gcsNode.LocalClient.AutopilotType); 
heartbeat.Payload.system_status(:) = enum2num(dialect,'MAV_STATE',"MAV_STATE_STANDBY");
heartbeat.Payload.base_mode(:) = 192; %128+64

heartbeatTimer = timer; 
heartbeatTimer.ExecutionMode = 'fixedRate'; 
heartbeatTimer.TimerFcn = @(~,~)sendudpmsg(gcsNode,heartbeat,'192.168.2.2',MavLinkPort); 
start(heartbeatTimer);

%% Variables y valores de control
% Variables generales
ARM=0;
Modo=4; %Depth Hold=2 // Manual=4 // Stabilize=8
Gain_deseada=0.4;
n_anterior=0;
hdg_actual_ant=0;
sube_gain=0;
baja_gain=0;

% Valores control proporcional
kp=1/18;

hdg_final=0; %Angulo: -18000:18000
alt_final=double(Datos_GlobalPositionINT.alt(1,1));
disp("Altura final: " + alt_final + " mm");
disp("Objetivo a alcanzar: " + hdg_final/100 + "º");

% Mensaje control
manual_control = createmsg(dialect,"MANUAL_CONTROL"); 
manual_control.Payload.target(:) = 1; 
manual_control.Payload.x(:) = 0; 
manual_control.Payload.y(:) = 0;
manual_control.Payload.z(:) = 500;
manual_control.Payload.r(:)= 0;
manual_control.Payload.buttons(:)= 0;

while isempty(Datos_GlobalPositionINT.hdg)
    %Espero a que capturemos algún dato
end

joy = vrjoystick(1);
disp("Mando conectado");
tstart=tic;
salir=0;

while salir==0
    actions_buttons=0;
    [axes, buttons, povs] = read(joy); % Leemos el joystick
    [Gain]=funcion_NAMED_VALUE_FLOAT(NAMED_VALUE_FLOAT); %Leemos la ganancia

    %%%%%%%%%%%%%%%   BOTONES    %%%%%%%%%%%%%%%
    if buttons(1)==1  
        %actions_buttons=actions_buttons+1; %MOUNT CENTER
        salir=1;
        manual_control.Payload.target(:) = 1; 
        manual_control.Payload.x(:) = 0; 
        manual_control.Payload.y(:) = 0;
        manual_control.Payload.z(:) = 500;
        manual_control.Payload.r(:)= 0;
        manual_control.Payload.buttons(:)= 21; %Manual+Camera_center+DISARM
        pause(0.1);
        sendudpmsg(gcsNode,manual_control,"192.168.2.2",MavLinkPort);
    elseif buttons(5)==1
        actions_buttons=actions_buttons+512; %MOUNT_DOWN
    elseif buttons(6)==1
        actions_buttons=actions_buttons+1024; %MOUNT_UP
    end
    
    if buttons(2)==1
        if Modo~=2
            disp("DEPTH HOLD MODE");
        end
        Modo=2; %DEPTH_HOLD
    elseif buttons(3)==1
        if Modo~=4
            disp("MANUAL MODE");
        end
        Modo=4; %MANUAL
    elseif buttons(4)==1
        if Modo~=8
            disp("STABILIZE MODE");
        end
        Modo=8; %STABILIZE
    end
    actions_buttons=actions_buttons+Modo;

    if buttons(7)==1
        if ARM==1
            disp("DISARM");
        end
        ARM=0;
        actions_buttons=actions_buttons+16; %DISARM
    elseif buttons(8)==1 || ARM==1
        if ARM==0
            disp("ARM");
            alt_final=double(Datos_GlobalPositionINT.alt(1,n));
            disp("Altura final: " + alt_final + " mm");
        end
        ARM=1;
        actions_buttons=actions_buttons+64; %ARM
    end
    
    % Ángulo de cabeceo modificable
    if buttons(9)==1
        actions_buttons=actions_buttons+128; %SHIFT
        hdg_final=hdg_final-4500;
        if hdg_final<-18000
            hdg_final=hdg_final+36000;
        end
        pause(0.5);
    end
    if buttons(10)==1
        actions_buttons=actions_buttons+256; %SHIFT
        hdg_final=hdg_final+4500;
        if hdg_final>18000
            hdg_final=hdg_final-36000;
        end
        pause(0.5);
    end

        %%%%%%%%%%%%%%%   FLECHAS    %%%%%%%%%%%%%%%
    if  round(single((Gain_deseada)),2)<round(Gain,2)
        actions_buttons=actions_buttons+4096;
        baja_gain=1;
    elseif  round(single((Gain_deseada)),2)>round(Gain,2)
        actions_buttons=actions_buttons+2048;
        sube_gain=1;
    end
        
    if (povs~=-1)
        if (povs==90) %ligths_up
            actions_buttons=actions_buttons+16384;
        elseif (povs==270) %ligths_down
            actions_buttons=actions_buttons+8192;
        end
    end
    
    %%%%%%%%%%%%%%%   JOYSTICKS    %%%%%%%%%%%%%%%
    if axes(3)<0
        hdg_final=hdg_final+100;
        if hdg_final>18000
            hdg_final=-18000;
        end
        pause(0.05);
    end
    if axes(3)>0
        hdg_final=hdg_final-100;
        if hdg_final<-18000
            hdg_final=18000;
        end
        pause(0.05);
    end    
    
    %% Realizamos el cálculo del control
    % HEADING
    [~,n]=size(Datos_GlobalPositionINT.hdg);
    
    if n_anterior~=n
        hdg_actual=double(Datos_GlobalPositionINT.hdg(1,n));
        
        if hdg_actual>18000
            hdg_actual=hdg_actual-36000; %-18000:18000
        end
        
        if abs(hdg_actual-hdg_actual_ant)>100 || hdg_actual_ant==0
            hdg_actual_ant=hdg_actual;
        end
        
        dif=hdg_final-hdg_actual;
        if dif>18000 
            dif=dif-36000;
        elseif dif<-18000
            dif=dif+36000;
        end
        
        vel=dif*kp; %vel=-1000:-300 y 300:1000
        
        if abs(dif)<1000
            Gain_deseada=0.3;
        else
            Gain_deseada=0.5;
        end
        
        
        if abs(vel)<300
            if dif>0
                vel=300;
            else
                vel=-300;
            end
        elseif abs(vel)>1000
            if dif>0
                vel=1000;
            else
                vel=-1000;
            end
        end
        
        if hdg_actual<hdg_final-500
            manual_control.Payload.r(:)= vel; %de 300 a 1000
        elseif hdg_actual>hdg_final+500
            manual_control.Payload.r(:)= vel; %-300 
        elseif hdg_actual>hdg_final-500 || hdg_actual<hdg_final+500
            manual_control.Payload.r(:)= 0;
            disp("Posicion Alcanzada");
        end
        
        % ALTURA
        alt_actual=double(Datos_GlobalPositionINT.alt(1,n));

        disp("Altura actual: " + alt_actual + " mm");
        dif_alt=alt_final-alt_actual;
        if dif_alt>50
            manual_control.Payload.z(:) = 1000;
        elseif dif_alt<-50
            manual_control.Payload.z(:) = 0;
        end
        
        %---------------------------------------------------------
        n_anterior=n;
    end
    
    %% Transmisión del mensaje
    if salir==0
        manual_control.Payload.buttons(:)= actions_buttons;
        sendudpmsg(gcsNode,manual_control,"192.168.2.2",MavLinkPort);
        
        if toc(tstart)>1
            tstart=tic;
            %[Gain]=funcion_NAMED_VALUE_FLOAT(NAMED_VALUE_FLOAT);
            fprintf('Ganancia:');
            fprintf(' %.1f \n', Gain);
            disp("----------------");
        end
        
        if  round(single((Gain_deseada)),2)~=round(Gain,2)
            if sube_gain==1
                manual_control.Payload.buttons(:)= actions_buttons-2048;
            elseif baja_gain==1
                manual_control.Payload.buttons(:)= actions_buttons-4096;
            end
            sendudpmsg(gcsNode,manual_control,"192.168.2.2",MavLinkPort);
            baja_gain=0;
            sube_gain=0;
            pause(0.2);
        end
    end
end

%% Desconectar GCS matlab
delete(heartbeatTimer); 
delete(AttitudeTimer);
delete(GlobalPositionINTTimer);
delete(SYS_STATUSTimer);
disconnect(gcsNode);

%% Limpiar variables
pause(0.01);
close(joy);
clear all
clc

%% FUNCIONES CALLBACK PARA ALMACENAR DATOS
function AttitudeCallback()
    global Datos_Attitude Attitude
    New_Atti = latestmsgs(Attitude,1);
    
    if isempty(New_Atti)==0
        %Almacenar datos
        Datos_Attitude.time_boot_ms=[Datos_Attitude.time_boot_ms New_Atti.Payload.time_boot_ms];
        Datos_Attitude.roll=[Datos_Attitude.roll New_Atti.Payload.roll];
        Datos_Attitude.pitch=[Datos_Attitude.pitch New_Atti.Payload.pitch];
        Datos_Attitude.yaw=[Datos_Attitude.yaw New_Atti.Payload.yaw];
        Datos_Attitude.rollspeed=[Datos_Attitude.rollspeed New_Atti.Payload.rollspeed];
        Datos_Attitude.pitchspeed=[Datos_Attitude.pitchspeed New_Atti.Payload.pitchspeed];
        Datos_Attitude.yawspeed=[Datos_Attitude.yawspeed New_Atti.Payload.yawspeed];
    end
end

function GlobalPositionINTCallback()
    global Datos_GlobalPositionINT GlobalPositionINT
    New_GPI = latestmsgs(GlobalPositionINT,1);
    
    if isempty(New_GPI)==0
        %Almacenar datos
        Datos_GlobalPositionINT.time_boot_ms=[Datos_GlobalPositionINT.time_boot_ms New_GPI.Payload.time_boot_ms];
        Datos_GlobalPositionINT.lat=[Datos_GlobalPositionINT.lat New_GPI.Payload.lat];
        Datos_GlobalPositionINT.lon=[Datos_GlobalPositionINT.lon New_GPI.Payload.lon];
        Datos_GlobalPositionINT.alt=[Datos_GlobalPositionINT.alt New_GPI.Payload.alt];
        Datos_GlobalPositionINT.relative_alt=[Datos_GlobalPositionINT.relative_alt New_GPI.Payload.relative_alt];
        Datos_GlobalPositionINT.vx=[Datos_GlobalPositionINT.vx New_GPI.Payload.vx];
        Datos_GlobalPositionINT.vy=[Datos_GlobalPositionINT.vy New_GPI.Payload.vy];
        Datos_GlobalPositionINT.vz=[Datos_GlobalPositionINT.vz New_GPI.Payload.vz];
        Datos_GlobalPositionINT.hdg=[Datos_GlobalPositionINT.hdg New_GPI.Payload.hdg];
    end
end

function SYS_STATUSCallback()
    global SYS_STATUS
    New_SS = latestmsgs(SYS_STATUS,1);
    
    if isempty(New_SS)==0
        fprintf('Batería: %.2f V\n', New_SS.Payload.voltage_battery/1000);
        if New_SS.Payload.voltage_battery<15000
            disp("CUIDADO: Batería baja");
        end
        disp("----------------");

    end
end

function [Gain] = funcion_NAMED_VALUE_FLOAT(NAMED_VALUE_FLOAT)
    New_NVF = latestmsgs(NAMED_VALUE_FLOAT,7);
    if isempty(New_NVF)==0
        for i=1:7
            if strcmp(convertCharsToStrings(New_NVF(i).Payload.name(1:9)), "PilotGain")
                Gain=New_NVF(i).Payload.value;
            end
        end
    end
end
