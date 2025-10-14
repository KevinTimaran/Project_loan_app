//#########################################
//# esta es la pantalla principal de la app, con busqueda de clientes y acceso a modulos
//#########################################

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/presentation/screens/clients/client_detail_screen.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/presentation/screens/payments/daily_payments_screen.dart';
import 'package:loan_app/presentation/screens/loans/active_loans_screen.dart';
import 'package:loan_app/presentation/screens/payments/weekly_payments_screen.dart';
import 'package:loan_app/presentation/screens/payments/today_collection_screen.dart';
import 'package:loan_app/presentation/screens/loans/simulator_screen.dart';
import 'package:provider/provider.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';
import 'package:intl/intl.dart';
// ✅ Importar la pantalla de historial real
import 'package:loan_app/presentation/screens/payments/payment_history_screen.dart';
// ✅ NUEVO: Importar url_launcher
import 'package:url_launcher/url_launcher.dart';


class CreatorInfoScreen extends StatelessWidget {
  const CreatorInfoScreen({super.key});

  // Helper para construir las filas de información no interactivas
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1E88E5), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Método para fila de email copiable con feedback visual
  Widget _buildCopyableEmailRow(BuildContext context, IconData icon, String title, String email) {
    return InkWell(
      onTap: () async {
        // Copiar el email al portapapeles
        await Clipboard.setData(ClipboardData(text: email));
        
        // Mostrar mensaje de confirmación
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Correo copiado: $email'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF43A047), // Verde de éxito
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1E88E5), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Toca para copiar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E88E5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.content_copy, color: Color(0xFF1E88E5), size: 18),
          ],
        ),
      ),
    );
  }

  // ✅ MÉTODO CORREGIDO: Manejo de URL más robusto
  Widget _buildLinkRow(BuildContext context, IconData icon, String title, String url) {
    return InkWell(
      onTap: () async {
        try {
          // 1. Asegurar que la URL tenga un esquema (https://)
          String validatedUrl = url.contains('://') ? url : 'https://$url';
          final uri = Uri.parse(validatedUrl);
          
          // 2. Verificar si el enlace se puede abrir
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri, 
              mode: LaunchMode.externalApplication, // Abrir en navegador externo
            );
          } else {
            // Manejar la imposibilidad de abrir
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudo abrir el enlace. Verifica la URL: $validatedUrl'),
                backgroundColor: const Color(0xFFE53935), // Rojo de error
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          // Manejar errores de parseo o lanzamiento
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar el enlace: $e'),
              backgroundColor: const Color(0xFFE53935),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1E88E5), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E88E5),
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFF1E88E5), size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información del Creador'),
        backgroundColor: const Color(0xFF1E88E5),
        iconTheme: const IconThemeData(color: Colors.white), // Color del ícono de atrás
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFF1E88E5),
              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'LoanApp',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Versión 1.0.0',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Desarrollado por:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Kevin Buesaquillo', 
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 15),
                    // ✅ Email copiable con feedback
                    _buildCopyableEmailRow(context, Icons.email, 'Email:', 'kevinstiventimaran@gmail.com'),
                    const SizedBox(height: 10),
                    // ✅ Enlace con manejo de URL robusto
                    _buildLinkRow(
                      context,
                      Icons.link, 
                      'Contacto Digital:', 
                      // Se pasa la URL sin https para que el método la añada si es necesario
                      'linktr.ee/Kevin_Buesaquillo' 
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.code, 'Tecnologías:', 'Flutter, Dart, Hive'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Hola, mi nombre es Kevin Stiven y te presento mi primera aplicación, LoanApp. Esta  '
                  'herramienta está diseñada para la gestión eficiente de préstamos, clientes y pagos, '
                  'ofreciendo un control financiero completo y seguimiento de cuentas por cobrar. Agradezco tu '
                  'paciencia con cualquier error que puedas encontrar. Para sugerencias o como podria mejorar, puedes '
                  'comunicarte conmigo a kevinstiventimaran@gmail.com.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//                           PANTALLA PRINCIPAL (HOME)
// -----------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ClientRepository _clientRepository = ClientRepository();
  List<Client> _foundClients = [];
  bool _isOptionsExpanded = false;
  late AnimationController _arrowAnimationController;
  late Animation<double> _arrowAnimation;

  // ✅ NUEVO: FocusNode para controlar el teclado
  final FocusNode _searchFocusNode = FocusNode();

  // ✅ Cache de clientes para la pestaña de Historial
  Map<String, Client> _clientCache = {};
  bool _isLoadingClients = true;

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arrowAnimation = Tween(begin: 0.0, end: 0.5).animate(_arrowAnimationController);
    _searchController.addListener(_onSearchChanged);
    _loadClients(); // ✅ Cargar clientes para el historial
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _arrowAnimationController.dispose();
    // ✅ NUEVO: Dispose del FocusNode
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ✅ NUEVO: Método para cerrar el teclado
  void _closeKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _toggleOptionsExpanded() {
    setState(() {
      _isOptionsExpanded = !_isOptionsExpanded;
      if (_isOptionsExpanded) {
        _arrowAnimationController.forward();
        _closeKeyboard(); // ✅ Cerrar teclado al expandir opciones
      } else {
        _arrowAnimationController.reverse();
      }
    });
  }

  void _onSearchChanged() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isNotEmpty) {
      final clients = await _clientRepository.searchClients(searchTerm);
      setState(() {
        _foundClients = clients;
      });
    } else {
      setState(() {
        _foundClients = [];
      });
    }
  }

  // ✅ Cargar clientes para el historial
  Future<void> _loadClients() async {
    try {
      final clientRepository = ClientRepository();
      final clients = await clientRepository.getAllClients();
      
      setState(() {
        _clientCache = {for (var client in clients) client.id: client};
        _isLoadingClients = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  Future<void> _clearAllHiveBoxes() async {
    try {
      await Hive.deleteBoxFromDisk('clients');
      await Hive.deleteBoxFromDisk('loans');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bases de datos de clientes y préstamos borradas correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al borrar las bases de datos: $e')),
      );
    }
  }

  /// Formatea un ID (UUID o numérico) en 5 dígitos numéricos
  String _formatIdAsFiveDigits(dynamic rawId) {
    if (rawId == null) return '00000';
    
    final rawString = rawId.toString();
    final digitsOnly = rawString.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      return '00000';
    } else if (digitsOnly.length <= 5) {
      return digitsOnly.padLeft(5, '0');
    } else {
      return digitsOnly.substring(digitsOnly.length - 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Define TODOS los colores AL PRINCIPIO del build
    final Color kHeaderColor = const Color(0xFF1E88E5);
    final Color kPrimaryButtonColor = const Color(0xFF43A047);
    final Color kTextColor = const Color(0xFF212121);
    final Color kAlertRed = const Color(0xFFE53935);
    final Color kOrangeModule = const Color(0xFFFB8C00);
    final Color kPurpleModule = Colors.purple.shade700;

    return DefaultTabController(
      length: 3, // Inicio, Cobros, Historial
      child: GestureDetector(
        // ✅ NUEVO: GestureDetector en toda la pantalla para cerrar teclado
        onTap: _closeKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: kHeaderColor,
            title: const Text(
              'LoanApp',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            centerTitle: true,
            elevation: 0,
            bottom: TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Inicio'),
                Tab(text: 'Cobros'),
                Tab(text: 'Historial'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // === Pestaña 1: INICIO (Tu pantalla principal) ===
              GestureDetector(
                // ✅ NUEVO: GestureDetector adicional para la pestaña de inicio
                onTap: _closeKeyboard,
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ MODIFICADO: Card de bienvenida convertido en botón
                      InkWell(
                        onTap: () {
                          _closeKeyboard();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreatorInfoScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 24),
                          child: const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Text(
                                  'Bienvenido a LoanApp',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E88E5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Gestiona tus préstamos, clientes y pagos de manera eficiente y segura.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ✅ CORREGIDO: TextField con FocusNode
                      TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode, // ✅ NUEVO: Asignar FocusNode
                        decoration: InputDecoration(
                          labelText: 'Buscar Cliente',
                          hintText: 'Nombre o ID',
                          prefixIcon: Icon(Icons.search, color: kHeaderColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: kHeaderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: kHeaderColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_foundClients.isNotEmpty) ...[
                        Text(
                          'Resultados de la búsqueda',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _foundClients.length,
                          itemBuilder: (context, index) {
                            final client = _foundClients[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                title: Text(
                                  '${client.name} ${client.lastName}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text('ID: ${client.identification}'),
                                onTap: () {
                                  _closeKeyboard(); // ✅ Cerrar teclado antes de navegar
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ClientDetailScreen(clientId: client.id),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      InkWell(
                        onTap: _toggleOptionsExpanded,
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                          decoration: BoxDecoration(
                            color: kHeaderColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: kHeaderColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Más Opciones',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: kHeaderColor,
                                ),
                              ),
                              RotationTransition(
                                turns: _arrowAnimation,
                                child: Icon(Icons.arrow_drop_down, color: kHeaderColor, size: 32),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: _isOptionsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: Container(),
                        secondChild: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildFeatureCard(
                              context,
                              icon: Icons.attach_money,
                              title: 'Préstamos',
                              onTap: () {
                                _closeKeyboard();
                                Navigator.of(context).pushNamed('/loanList');
                              },
                              iconColor: kPrimaryButtonColor,
                            ),
                            _buildFeatureCard(
                              context,
                              icon: Icons.people,
                              title: 'Clientes',
                              onTap: () {
                                _closeKeyboard();
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const ClientListScreen()),
                                );
                              },
                              iconColor: kOrangeModule,
                            ),
                            _buildFeatureCard(
                              context,
                              icon: Icons.calculate,
                              title: 'Simulador',
                              onTap: () {
                                _closeKeyboard();
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const SimulatorScreen()),
                                );
                              },
                              iconColor: Colors.teal,
                            ),
                            _buildFeatureCard(
                              context,
                              icon: Icons.calendar_today,
                              title: 'Pagos del Día',
                              onTap: () {
                                _closeKeyboard();
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const DailyPaymentsScreen()),
                                );
                              },
                              iconColor: kHeaderColor,
                            ),
                            // ✅ Corregido: Navegar a Préstamos Activos
                            _buildFeatureCard(
                              context,
                              icon: Icons.history,
                              title: 'Préstamos Activos',
                              onTap: () {
                                _closeKeyboard();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ActiveLoansScreen()),
                                );
                              },
                              iconColor: kPurpleModule,
                            ),
                            // ✅ AÑADIDO: Borrar Bases de Datos
                            _buildFeatureCard(
                              context,
                              icon: Icons.delete_forever,
                              title: 'Borrar Bases de Datos',
                              onTap: () {
                                _closeKeyboard();
                                _clearAllHiveBoxes();
                              },
                              iconColor: kAlertRed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // === Pestaña 2: COBROS (Con sub-pestañas) ===
              GestureDetector(
                // ✅ NUEVO: También para la pestaña de cobros
                onTap: _closeKeyboard,
                child: DefaultTabController(
                  length: 2,
                  child: Scaffold(
                    // Eliminamos el toolbar vacío que dejaba espacio arriba
                    appBar: AppBar(
                      toolbarHeight: 0,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      bottom: TabBar(
                        indicatorColor: kHeaderColor,
                        labelColor: kHeaderColor,
                        unselectedLabelColor: kTextColor.withOpacity(0.7),
                        tabs: const [
                          Tab(text: 'Hoy'),
                          Tab(text: 'Semana'),
                        ],
                      ),
                    ),
                    body: TabBarView(
                      children: [
                        // --- Cobros Hoy ---
                        const TodayCollectionScreen(), // ✅ se usa la pantalla real

                        // --- Cobros Semana ---
                        const WeeklyPaymentsScreen(), // ✅ se usa la pantalla real
                      ],
                    ),
                  ),
                ),
              ),

              // === Pestaña 3: HISTORIAL ===
              // ✅ Filtrar SOLO préstamos pagados
              GestureDetector(
                // ✅ NUEVO: También para la pestaña de historial
                onTap: _closeKeyboard,
                child: Consumer<LoanProvider>(
                  builder: (context, loanProvider, child) {
                    if (loanProvider.isLoading || _isLoadingClients) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (loanProvider.errorMessage != null) {
                      return Center(
                        child: Text('Error: ${loanProvider.errorMessage}'),
                      );
                    }

                    // ✅ FILTRO CLAVE: Solo préstamos pagados
                    final paidLoans = loanProvider.loans
                        .where((loan) => loan.status == 'pagado')
                        .toList();

                    if (paidLoans.isEmpty) {
                      return const Center(
                        child: Text('No hay préstamos pagados aún.'),
                      );
                    }

                    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

                    return ListView.builder(
                      itemCount: paidLoans.length,
                      itemBuilder: (context, index) {
                        final loan = paidLoans[index];
                        final client = _clientCache[loan.clientId];
                        final clientName = client != null ? '${client.name} ${client.lastName}' : 'Cliente no encontrado';
                        final loanIdDisplay = _formatIdAsFiveDigits(loan.id); // ✅ ID en 5 dígitos

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text('Préstamo #$loanIdDisplay - ${currencyFormatter.format(loan.amount)}'),
                            subtitle: Text('Cliente: $clientName\nEstado: ${loan.status}'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              _closeKeyboard(); // ✅ Cerrar teclado antes de navegar
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => LoanDetailScreen(loan: loan)),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}