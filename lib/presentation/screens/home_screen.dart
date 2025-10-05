//#########################################
//# esta es la pantalla principal de la app, con busqueda de clientes y acceso a modulos
//#########################################

import 'package:flutter/material.dart';
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
// ✅ Importaciones agregadas para la pestaña de Historial
import 'package:provider/provider.dart';
import 'package:loan_app/presentation/providers/loan_provider.dart';
import 'package:loan_app/presentation/screens/loans/loan_detail_screen.dart';
import 'package:intl/intl.dart';

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
    super.dispose();
  }

  void _toggleOptionsExpanded() {
    setState(() {
      _isOptionsExpanded = !_isOptionsExpanded;
      if (_isOptionsExpanded) {
        _arrowAnimationController.forward();
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
          actions: [
            IconButton(
              icon: const Icon(Icons.cleaning_services, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirmar Borrado General'),
                    content: const Text('Esta acción borrará todos los clientes y préstamos. ¿Estás seguro?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _clearAllHiveBoxes();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: kAlertRed),
                        child: const Text('Borrar Todo'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Borrar todas las bases de datos (solo para pruebas)',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // === Pestaña 1: INICIO (Tu pantalla principal) ===
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            'Bienvenido a LoanApp',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kHeaderColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Gestiona tus préstamos, clientes y pagos de manera eficiente y segura.',
                            style: TextStyle(fontSize: 16, color: kTextColor.withOpacity(0.8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  TextField(
                    controller: _searchController,
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
                          onTap: () => Navigator.of(context).pushNamed('/loanList'),
                          iconColor: kPrimaryButtonColor,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.people,
                          title: 'Clientes',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ClientListScreen()),
                          ),
                          iconColor: kOrangeModule,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.payment,
                          title: 'Registrar Pago',
                          onTap: () => Navigator.of(context).pushNamed('/addPayment'),
                          iconColor: kPurpleModule,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.calendar_today,
                          title: 'Pagos del Día',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const DailyPaymentsScreen()),
                          ),
                          iconColor: kHeaderColor,
                        ),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Icon(Icons.history, color: kHeaderColor),
                            title: const Text('Historial de Préstamos', textAlign: TextAlign.center),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ActiveLoansScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // === Pestaña 2: COBROS (Con sub-pestañas) ===
            DefaultTabController(
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

            // === Pestaña 3: HISTORIAL ===
            // ✅ Reemplazado el mensaje de "Próximamente" con la lista real de préstamos
            Consumer<LoanProvider>(
              builder: (context, loanProvider, child) {
                if (loanProvider.isLoading || _isLoadingClients) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (loanProvider.errorMessage != null) {
                  return Center(
                    child: Text('Error: ${loanProvider.errorMessage}'),
                  );
                }
                if (loanProvider.loans.isEmpty) {
                  return const Center(
                    child: Text('No hay préstamos registrados.'),
                  );
                }

                final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

                return ListView.builder(
                  itemCount: loanProvider.loans.length,
                  itemBuilder: (context, index) {
                    final loan = loanProvider.loans[index];
                    final client = _clientCache[loan.clientId];
                    final clientName = client != null ? '${client.name} ${client.lastName}' : 'Cliente no encontrado';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text('Préstamo #${loan.id.substring(0, 5)} - ${currencyFormatter.format(loan.amount)}'),
                        subtitle: Text('Cliente: $clientName\nEstado: ${loan.status}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
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
          ],
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