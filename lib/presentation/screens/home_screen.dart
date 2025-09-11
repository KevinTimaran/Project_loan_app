// lib/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loan_app/data/repositories/client_repository.dart';
import 'package:loan_app/domain/entities/client.dart';
import 'package:loan_app/presentation/screens/clients/client_detail_screen.dart';
import 'package:loan_app/presentation/screens/clients/client_list_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loan_app/presentation/screens/payments/daily_payments_screen.dart'; // <--- Importación AÑADIDA
import 'package:loan_app/presentation/screens/loans/active_loans_screen.dart';
import 'package:loan_app/presentation/screens/loans/loan_list_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _arrowAnimation = Tween(begin: 0.0, end: 0.5).animate(_arrowAnimationController);
    _searchController.addListener(_onSearchChanged);
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
    final Color primaryBlue = Theme.of(context).appBarTheme.backgroundColor ?? Colors.blue;
    final Color mainGreen = const Color(0xFF43A047);
    final Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final Color alertRed = const Color(0xFFE53935);
    final Color orangeModule = Colors.orange.shade700;
    final Color purpleModule = Colors.purple.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LoanApp - Inicio',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Bienvenido a LoanApp',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Gestiona tus préstamos, clientes y pagos de manera eficiente.',
                      style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar Cliente rápidamente',
                  hintText: 'Nombre o ID del cliente',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  suffixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            
            if (_foundClients.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _foundClients.length,
                itemBuilder: (context, index) {
                  final client = _foundClients[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('${client.name} ${client.lastName}'),
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

            InkWell(
              onTap: _toggleOptionsExpanded,
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: primaryBlue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Más Opciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                    RotationTransition(
                      turns: _arrowAnimation,
                      child: Icon(Icons.keyboard_arrow_down, color: primaryBlue),
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
                childAspectRatio: 1.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildFeatureCard(
                    context,
                    icon: Icons.attach_money,
                    title: 'Gestión de Préstamos',
                    onTap: () {
                      Navigator.of(context).pushNamed('/loanList');
                    },
                    iconColor: mainGreen,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.people,
                    title: 'Gestión de Clientes',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ClientListScreen()),
                      );
                    },
                    iconColor: orangeModule,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.payment,
                    title: 'Registro de Pagos',
                    onTap: () {
                      Navigator.of(context).pushNamed('/addPayment');
                    },
                    iconColor: purpleModule,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.calendar_today,
                    title: 'Ver Pagos del Día',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DailyPaymentsScreen()),
                      );
                    },
                    iconColor: Colors.blue.shade700,
                  ),
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: const Icon(Icons.history, color: Colors.blue),
                      title: const Text('Ver Historial de Préstamos'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ActiveLoansScreen()),                        );
                      },
                    ),
                  ),
                
                ],
              ),
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
    final Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: iconColor),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}