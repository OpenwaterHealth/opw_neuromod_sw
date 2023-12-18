function vsx_log_xmit()
% VSX_LOG_XMIT log and increment the transmit index
%
% VSX_LOG_XMIT is called from the Event sequence as an external Process
% call. It identifies the VSX_PROGRESS_GUI and updates the progress bar to
% indicate the transmission of a treatment pules, and then increments the
% transmit index
app_var = 'vsx_app'; 
app = evalin('caller', app_var);
app.update();
if isvalid(app)
    app.set_pulse(app.pulse_index+1);
end
return
