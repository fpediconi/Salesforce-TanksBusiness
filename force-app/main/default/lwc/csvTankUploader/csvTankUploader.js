import { LightningElement, track, wire } from 'lwc';
import insertTanks from '@salesforce/apex/BulkTankUploader.insertTanks';
import getAllTankTypes from '@salesforce/apex/TankTypeController.getAllTankTypes';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import PapaParse from '@salesforce/resourceUrl/PapaParse';
import './csvTankUploader.css';
import { refreshApex } from '@salesforce/apex';

// =========================
// 1) DEFINICIÓN DE COLUMNAS para lightning-datatable
// =========================
//   - index:           indice original de la fila en el CSV
//   - serialNumber:    el SerialNumber que se envio a Apex
//   - success:         boolean si se inserto o no
//   - recordId:        Id de registro creado (si tuvo éxito)
//   - errorMessage:    mensaje de error (finger cross)
const COLUMNS = [
    { label: 'Índice',         fieldName: 'index',         type: 'number', sortable: true },
    { label: 'Serial Number',  fieldName: 'serialNumber',  type: 'text' },
    { label: 'Éxito',          fieldName: 'success',       type: 'boolean' },
    { label: 'Record Id',      fieldName: 'recordId',      type: 'text' },
    { label: 'Mensaje Error',  fieldName: 'errorMessage',  type: 'text' }
];

export default class csvTankUploader extends LightningElement {
    // =========================
    // 2) PROPIEDADES REACTIVAS
    // =========================
    @track parsedData = [];           // arreglo de objetos { SerialNumber, Status }
    @track uploadResults = [];        // PASA a ser un array (no null) con resultados post-Apex
    @track tankTypeOptions = [];      // opciones para el combobox de tipos de tank
    @track isUploadDisabled = true;   // controla si el botón procesar está deshabilitado
    @track isLoading = false;         // controla la visibilidad del spinner
    @track columns = COLUMNS;         // columnas para lightning-datatable
    @track showModal = false;         // controla la visibilidad del modal

    // =========================
    // 3) PROPIEDADES NO-REACTIVAS
    // =========================
    selectedTankTypeId = '';        // Id del Tank Type escogido
    papaLoaded = false;             // indica si PapaParse ya esta ok
    fileName = '';                  // guarda el nombre del CSV seleccionado
    lastCreatedTankTypeId = null;   // guarda el último Tank Type creado (para refrescar la lista)
    wiredTankTypesResult;           // para guardar el wire

    // =========================
    // 4) WIRE: Obtener todos los Tank Types para el combobox
    // =========================
    @wire(getAllTankTypes)
    wiredTankTypes(result) {
        this.wiredTankTypesResult = result; // GUARDAMOS el wire para usar en refreshApex

        const { data, error } = result;
        if (data) {
            this.tankTypeOptions = data.map(item => ({
                label: item.name,
                value: item.id
            }));
        } else if (error) {
            console.error('ERROR getAllTankTypes:', error);
        }
    }

    // =========================
    // 5) Handler: cambio de Tank Type en el combobox
    // =========================
    handleTankTypeChange(event) {
        this.selectedTankTypeId = event.detail.value;
    }

    

    // =========================
    // 6) Handler: cuando el usuario elige un archivo CSV
    // =========================
    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) {
            this.fileName = '';
            this.isUploadDisabled = true;
            this.parsedData = [];
            return;
        }
        this.fileName = file.name;
        this.parsedData = [];
        this.isUploadDisabled = true;

        const reader = new FileReader();
        reader.onload = () => {
            // Validamos que PapaParse ya este cargado
            if (typeof Papa === 'undefined') {
                console.warn('WARN: PapaParse no está definido aún.');
                return;
            }
            const csv = reader.result;
            Papa.parse(csv, {
                header: true,
                skipEmptyLines: true,
                complete: (results) => {
                    // Depuramos que esta leyendo PapaParse
                    console.log('--- DEBUG Antes de mapear rawArray ---');
                    results.data.forEach((row, idx) => {
                        console.log(
                            `ROW ${idx}: keys=[${Object.keys(row).join(',')}], ` +
                            `values=[${Object.values(row).join(',')}]`
                        );
                    });

                    // Mapeamos solo SerialNumber y Status
                    this.parsedData = results.data.map((row) => ({
                        SerialNumber: row['SerialNumber'] ? row['SerialNumber'].trim() : '',
                        Status:       row['Status']       ? row['Status'].trim()       : ''
                    }));
                    console.log('--- DEBUG parsedData resultante ---', this.parsedData);

                    // Habilitamos el botón de "Procesar"
                    this.isUploadDisabled = false;
                },
                error: (err) => {
                    console.error('ERROR durante Papa.parse:', err);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error parseando CSV',
                            message: err.message,
                            variant: 'error'
                        })
                    );
                }
            });
        };
        reader.readAsText(file);
    }

    // =========================
    // 7) Handler: al hacer clic en "Procesar CSV e importar"
    // =========================
    handleUpload() {
        // A) Validaciones previas
        if (!this.selectedTankTypeId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Debe elegir un tipo de tanque primero.',
                    variant: 'error'
                })
            );
            return;
        }
        if (!this.parsedData || this.parsedData.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No hay datos del CSV para procesar.',
                    variant: 'error'
                })
            );
            return;
        }

        // B) Inyectar TankTypeId en cada objeto
        const tankWrappers = this.parsedData.map((row, idx) => ({
            SerialNumber: row.SerialNumber,
            Status:       row.Status,
            TankTypeId:   this.selectedTankTypeId
        }));

        console.log('=== Antes de stringify: tankWrappers ===');
        console.table(tankWrappers);
        console.log('=== JSON.stringify(tankWrappers) ===');
        console.log(JSON.stringify(tankWrappers, null, 2));

        // C) mostramos spinner y deshabilitamos el botón
        this.isLoading = true;
        this.isUploadDisabled = true;

        // D) Llamada a Apex
        insertTanks({ tankWrappers: JSON.parse(JSON.stringify(tankWrappers)) })
            .then(resultArray => {
                
                // E) Mezclamos cada UploadResult con el SerialNumber original
                this.uploadResults = resultArray.map(r => {
                    // Obtenemos el SerialNumber de la fila original:
                    const serial = (tankWrappers[r.index] && tankWrappers[r.index].SerialNumber) 
                                   ? tankWrappers[r.index].SerialNumber 
                                   : '';
                    return {
                        index:        r.index,
                        serialNumber: serial,
                        success:      r.success,
                        recordId:     r.recordId,
                        errorMessage: r.errorMessage
                    };
                });

                // F) Toast informativo según al menos un éxito
                const anySuccess = resultArray.some(r => r.success);
                if (anySuccess) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Importación completada',
                            message: 'Revisa los resultados debajo.',
                            variant: 'success'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error en la importación',
                            message: 'Ninguna fila se pudo insertar.',
                            variant: 'error'
                        })
                    );
                }

                // G) Ocultamos spinner (seguirá mostrando la tabla)
                this.isLoading = false;
            })
            .catch(error => {
                console.error('ERROR insertTanks:', error);
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error en Apex',
                        message: error.body?.message || error.message,
                        variant: 'error'
                    })
                );
            });
    }

    // =========================
    // 8) Carga de PapaParse en renderedCallback
    // =========================
    renderedCallback() {
        if (this.papaLoaded) {
            return;
        }
        loadScript(this, PapaParse + '/papaparse.min.js')
            .then(() => {
                this.papaLoaded = true;
                console.log('DEBUG: PapaParse cargado correctamente');
            })
            .catch(error => {
                console.error('ERROR cargando PapaParse:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error cargando PapaParse',
                        message: error.message,
                        variant: 'error'
                    })
                );
            });
    }

    // =========================
    // 9) Getter para deshabilitar el input de archivo
    // =========================
    get isFileInputDisabled() {
        return !this.selectedTankTypeId || !this.papaLoaded;
    }

    // =========================
    // 10) Funciones para abrir la carga de tank type desde un modal (sadly la carga nativa de salesforce no funciono)
    // =========================
    handleCreateNewTankType() {
        this.showModal = true;
    }
    closeModal() {
        this.showModal = false;
    }

    handleNewTankTypeCreated(event) {
        console.log('Nuevo Tank Type creado con ID:', event.detail.id);
        this.showModal = false;
        const newId = event.detail.id;
        this.lastCreatedTankTypeId = newId;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Tipo de tanque creado',
                message: 'Nuevo tipo de tanque creado con éxito.',
                variant: 'success'
            })
        );

        refreshApex(this.wiredTankTypesResult).then(() => {
            this.selectedTankTypeId = newId;
        });

        setTimeout(() => {
            this.selectedTankTypeId = newId;
        }, 300);
    }


}

